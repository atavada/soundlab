import CoreAudio
import Foundation

#if canImport(AppKit)
import AppKit
#endif

public typealias ProcessAppInfoProvider = @Sendable (pid_t) -> (name: String, bundleID: String?)?

#if canImport(AppKit)
public let defaultProcessAppInfoProvider: ProcessAppInfoProvider = { pid in
    guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
    return (name: app.localizedName ?? "Process \(pid)", bundleID: app.bundleIdentifier)
}
#else
public let defaultProcessAppInfoProvider: ProcessAppInfoProvider = { pid in
    return (name: "Process \(pid)", bundleID: nil)
}
#endif

@available(macOS 14.2, *)
public final class ProcessAudioMixer: @unchecked Sendable {
    #if canImport(AppKit)
    public static let didTerminateApplicationNotification = NSWorkspace.didTerminateApplicationNotification
    #else
    public static let didTerminateApplicationNotification = Notification.Name("NSWorkspaceDidTerminateApplicationNotification")
    #endif

    private let lock = NSLock()

    private let tapService: ProcessTapServiceProtocol
    private let deviceManager: DeviceManager
    private let settingsManager: SettingsManager
    private let appInfoProvider: ProcessAppInfoProvider
    private let notificationCenter: NotificationCenter

    private var _activeTaps: [pid_t: ProcessTapController] = [:]
    private var _processes: [AudioProcess] = []
    private var _changeListeners: [@Sendable () -> Void] = []
    private var _currentOutputUID: String?
    private var terminationObserver: (any NSObjectProtocol)?

    public var processes: [AudioProcess] {
        lock.lock()
        defer { lock.unlock() }
        return _processes
    }

    public var activeTaps: [pid_t: ProcessTapController] {
        lock.lock()
        defer { lock.unlock() }
        return _activeTaps
    }

    public init(
        tapService: ProcessTapServiceProtocol,
        deviceManager: DeviceManager,
        settingsManager: SettingsManager,
        appInfoProvider: ProcessAppInfoProvider? = nil,
        notificationCenter: NotificationCenter = .default
    ) {
        self.tapService = tapService
        self.deviceManager = deviceManager
        self.settingsManager = settingsManager
        self.appInfoProvider = appInfoProvider ?? defaultProcessAppInfoProvider
        self.notificationCenter = notificationCenter
        self._currentOutputUID = deviceManager.defaultOutputDevice?.uid

        deviceManager.addChangeListener { [weak self] in
            self?.handleDeviceChange()
        }

        self.terminationObserver = notificationCenter.addObserver(
            forName: Self.didTerminateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleAppTerminatedNotification(notification)
        }
    }

    deinit {
        invalidate()
    }

    // MARK: - Core APIs

    public func refreshAudioProcesses() throws {
        let objectIDs = try tapService.getAudioProcessObjectIDs()
        let selfPID = ProcessInfo.processInfo.processIdentifier
        let outputUID = deviceManager.defaultOutputDevice?.uid

        struct DiscoveredProcess {
            let pid: pid_t
            let objectID: AudioObjectID
            let name: String
            let bundleID: String?
            let initialVolume: Float
        }

        var discovered: [DiscoveredProcess] = []
        var discoveredPIDs = Set<pid_t>()

        for objID in objectIDs {
            guard let pid = try? tapService.getPID(for: objID) else { continue }
            if pid == selfPID { continue }
            guard !discoveredPIDs.contains(pid) else { continue }
            discoveredPIDs.insert(pid)

            let appInfo = appInfoProvider(pid)
            let name = appInfo?.name ?? "Process \(pid)"
            let bundleID = appInfo?.bundleID

            let savedVolume = bundleID.flatMap { settingsManager.getAppVolume(forBundleID: $0) }
            let volume = savedVolume ?? 1.0

            discovered.append(DiscoveredProcess(
                pid: pid,
                objectID: objID,
                name: name,
                bundleID: bundleID,
                initialVolume: volume
            ))
        }

        var tapsToInvalidate: [ProcessTapController] = []
        var listeners: [@Sendable () -> Void] = []

        lock.lock()
        _currentOutputUID = outputUID

        // 1. Remove taps for processes no longer present
        for (pid, tap) in _activeTaps {
            if !discoveredPIDs.contains(pid) {
                _activeTaps.removeValue(forKey: pid)
                tapsToInvalidate.append(tap)
            }
        }

        // 2. Instantiate and activate taps for new processes
        for item in discovered {
            if _activeTaps[item.pid] == nil, let outUID = outputUID {
                let tap = ProcessTapController(
                    pid: item.pid,
                    processObjectID: item.objectID,
                    outputUID: outUID,
                    service: tapService,
                    initialVolume: item.initialVolume
                )
                do {
                    try tap.activate()
                    _activeTaps[item.pid] = tap
                } catch {
                    // Skip tap if activation fails
                }
            }
        }

        // 3. Build updated process models
        var updatedProcesses: [AudioProcess] = []
        for item in discovered {
            let tap = _activeTaps[item.pid]
            let vol = tap?.volume ?? item.initialVolume
            let muted = tap?.isMuted ?? false

            updatedProcesses.append(AudioProcess(
                pid: item.pid,
                objectID: item.objectID,
                bundleID: item.bundleID,
                name: item.name,
                isMuted: muted,
                volume: vol
            ))
        }

        updatedProcesses.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        _processes = updatedProcesses
        listeners = _changeListeners
        lock.unlock()

        for tap in tapsToInvalidate {
            tap.invalidate()
        }

        for listener in listeners {
            listener()
        }
    }

    public func setVolume(_ volume: Float, forPID pid: pid_t) throws {
        let clamped = min(max(volume, 0.0), 1.0)
        let listeners: [@Sendable () -> Void]
        let tap: ProcessTapController?
        let bundleID: String?

        lock.lock()
        guard let index = _processes.firstIndex(where: { $0.pid == pid }) else {
            lock.unlock()
            throw SoundLabAudioError.processNotFound(pid: pid)
        }

        _processes[index].volume = clamped
        bundleID = _processes[index].bundleID
        tap = _activeTaps[pid]
        listeners = _changeListeners
        lock.unlock()

        tap?.setVolume(clamped)
        if let bundleID = bundleID {
            settingsManager.saveAppVolume(clamped, forBundleID: bundleID)
        }

        for listener in listeners {
            listener()
        }
    }

    public func toggleMute(forPID pid: pid_t) throws {
        let listeners: [@Sendable () -> Void]
        let tap: ProcessTapController?
        let newMuted: Bool

        lock.lock()
        guard let index = _processes.firstIndex(where: { $0.pid == pid }) else {
            lock.unlock()
            throw SoundLabAudioError.processNotFound(pid: pid)
        }

        newMuted = !_processes[index].isMuted
        _processes[index].isMuted = newMuted
        tap = _activeTaps[pid]
        listeners = _changeListeners
        lock.unlock()

        tap?.setMuted(newMuted)

        for listener in listeners {
            listener()
        }
    }

    public func addChangeListener(_ listener: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        _changeListeners.append(listener)
    }

    // MARK: - Lifecycle Management

    public func handleProcessTerminated(pid: pid_t) {
        let tap: ProcessTapController?
        let listeners: [@Sendable () -> Void]

        lock.lock()
        tap = _activeTaps.removeValue(forKey: pid)
        let removed = _processes.contains { $0.pid == pid }
        _processes.removeAll { $0.pid == pid }
        listeners = _changeListeners
        lock.unlock()

        tap?.invalidate()

        if tap != nil || removed {
            for listener in listeners {
                listener()
            }
        }
    }

    public func handleAppTerminatedNotification(_ notification: Notification) {
        var terminatedPID: pid_t?

        #if canImport(AppKit)
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            terminatedPID = app.processIdentifier
        } else if let app = notification.object as? NSRunningApplication {
            terminatedPID = app.processIdentifier
        }
        #endif

        if terminatedPID == nil {
            if let pid = notification.userInfo?["NSApplicationProcessIdentifier"] as? pid_t {
                terminatedPID = pid
            } else if let num = notification.userInfo?["NSApplicationProcessIdentifier"] as? NSNumber {
                terminatedPID = pid_t(num.int32Value)
            } else if let pid = notification.userInfo?["pid"] as? pid_t {
                terminatedPID = pid
            } else if let num = notification.userInfo?["pid"] as? NSNumber {
                terminatedPID = pid_t(num.int32Value)
            }
        }

        if let pid = terminatedPID {
            handleProcessTerminated(pid: pid)
        }
    }

    public func invalidate() {
        let taps: [ProcessTapController]
        let listeners: [@Sendable () -> Void]

        lock.lock()
        if let observer = terminationObserver {
            notificationCenter.removeObserver(observer)
            terminationObserver = nil
        }
        taps = Array(_activeTaps.values)
        _activeTaps.removeAll()
        _processes.removeAll()
        listeners = _changeListeners
        lock.unlock()

        for tap in taps {
            tap.invalidate()
        }

        for listener in listeners {
            listener()
        }
    }

    private func handleDeviceChange() {
        let newUID = deviceManager.defaultOutputDevice?.uid
        var tapsToRecreate: [(tap: ProcessTapController, uid: String)] = []
        var tapsToActivate: [(pid: pid_t, objID: AudioObjectID, volume: Float, uid: String)] = []
        let listeners: [@Sendable () -> Void]

        lock.lock()
        guard newUID != _currentOutputUID else {
            lock.unlock()
            return
        }
        _currentOutputUID = newUID

        if let newUID = newUID {
            for tap in _activeTaps.values {
                tapsToRecreate.append((tap, newUID))
            }

            for proc in _processes {
                if _activeTaps[proc.pid] == nil {
                    tapsToActivate.append((pid: proc.pid, objID: proc.objectID, volume: proc.volume, uid: newUID))
                }
            }
        }
        listeners = _changeListeners
        lock.unlock()

        for item in tapsToRecreate {
            try? item.tap.recreate(newOutputUID: item.uid)
        }

        for item in tapsToActivate {
            let tap = ProcessTapController(
                pid: item.pid,
                processObjectID: item.objID,
                outputUID: item.uid,
                service: tapService,
                initialVolume: item.volume
            )
            if (try? tap.activate()) != nil {
                lock.lock()
                _activeTaps[item.pid] = tap
                lock.unlock()
            }
        }

        for listener in listeners {
            listener()
        }
    }
}
