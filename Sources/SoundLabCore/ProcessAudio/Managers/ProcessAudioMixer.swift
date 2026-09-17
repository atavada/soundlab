import CoreAudio
import Foundation

#if canImport(AppKit)
import AppKit
#endif
#if canImport(Darwin)
import Darwin
#endif

public struct ProcessAppInfo: Sendable, Equatable {
    public let pid: pid_t
    public let name: String
    public let bundleID: String?

    public init(pid: pid_t, name: String, bundleID: String? = nil) {
        self.pid = pid
        self.name = name
        self.bundleID = bundleID
    }
}

public typealias ProcessAppInfoProvider = @Sendable (pid_t) -> ProcessAppInfo?

#if canImport(AppKit) && canImport(Darwin)
private func getParentPID(pid: pid_t) -> pid_t? {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
    let ret = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
    if ret <= 0 { return nil }
    return pid_t(info.pbi_ppid)
}

public let defaultProcessAppInfoProvider: ProcessAppInfoProvider = { pid in
    // 1. Direct regular app check
    if let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
        guard let name = app.localizedName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ProcessAppInfo(pid: app.processIdentifier, name: name, bundleID: app.bundleIdentifier)
    }

    // 2. Parent PID traversal to find regular ancestor app (for Chromium/Electron/WebKit child helpers)
    var currentPID = pid
    var depth = 0
    while depth < 8 {
        guard let parentPID = getParentPID(pid: currentPID), parentPID > 1, parentPID != currentPID else { break }
        if let parentApp = NSRunningApplication(processIdentifier: parentPID), parentApp.activationPolicy == .regular {
            guard let name = parentApp.localizedName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return ProcessAppInfo(pid: parentApp.processIdentifier, name: name, bundleID: parentApp.bundleIdentifier)
        }
        currentPID = parentPID
        depth += 1
    }

    // 3. Bundle identifier prefix match fallback (e.g. for helpers launched via launchd/XPC)
    if let helperApp = NSRunningApplication(processIdentifier: pid), let helperBundle = helperApp.bundleIdentifier {
        for regularApp in NSWorkspace.shared.runningApplications where regularApp.activationPolicy == .regular {
            if let regBundle = regularApp.bundleIdentifier, !regBundle.isEmpty, helperBundle.hasPrefix(regBundle) {
                guard let name = regularApp.localizedName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                return ProcessAppInfo(pid: regularApp.processIdentifier, name: name, bundleID: regularApp.bundleIdentifier)
            }
        }
    }

    return nil
}
#else
public let defaultProcessAppInfoProvider: ProcessAppInfoProvider = { _ in nil }
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

        struct DiscoveredApp {
            let pid: pid_t
            let name: String
            let bundleID: String?
            var objectIDs: [AudioObjectID]
        }

        var discoveredMap: [pid_t: DiscoveredApp] = [:]

        for objID in objectIDs {
            guard let pid = try? tapService.getPID(for: objID) else { continue }
            if pid == selfPID { continue }

            guard let appInfo = appInfoProvider(pid) else { continue }
            if appInfo.pid == selfPID { continue }
            let trimmedName = appInfo.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { continue }
            if let bID = appInfo.bundleID, bID == Bundle.main.bundleIdentifier || bID == "com.atavada.SoundLab" {
                continue
            }

            if var existing = discoveredMap[appInfo.pid] {
                if !existing.objectIDs.contains(objID) {
                    existing.objectIDs.append(objID)
                    discoveredMap[appInfo.pid] = existing
                }
            } else {
                discoveredMap[appInfo.pid] = DiscoveredApp(
                    pid: appInfo.pid,
                    name: trimmedName,
                    bundleID: appInfo.bundleID,
                    objectIDs: [objID]
                )
            }
        }

        var tapsToInvalidate: [ProcessTapController] = []
        var tapsToActivate: [ProcessTapController] = []

        lock.lock()
        _currentOutputUID = outputUID

        // 1. Remove taps for apps no longer present
        for (pid, tap) in _activeTaps {
            if discoveredMap[pid] == nil {
                _activeTaps.removeValue(forKey: pid)
                tapsToInvalidate.append(tap)
            }
        }

        // 2. Update existing taps or instantiate new taps
        for (pid, appData) in discoveredMap {
            if let existingTap = _activeTaps[pid] {
                try? existingTap.updateProcessObjectIDs(appData.objectIDs)
            } else if let outUID = outputUID {
                let savedVolume = appData.bundleID.flatMap { settingsManager.getAppVolume(forBundleID: $0) }
                let volume = savedVolume ?? 1.0

                let tap = ProcessTapController(
                    pid: pid,
                    processObjectIDs: appData.objectIDs,
                    outputUID: outUID,
                    service: tapService,
                    initialVolume: volume
                )
                _activeTaps[pid] = tap
                tapsToActivate.append(tap)
            }
        }

        // 3. Build updated process models
        var updatedProcesses: [AudioProcess] = []
        for (pid, appData) in discoveredMap {
            let tap = _activeTaps[pid]
            let vol = tap?.volume ?? (appData.bundleID.flatMap { settingsManager.getAppVolume(forBundleID: $0) } ?? 1.0)
            let muted = tap?.isMuted ?? false

            updatedProcesses.append(AudioProcess(
                pid: pid,
                objectIDs: appData.objectIDs,
                bundleID: appData.bundleID,
                name: appData.name,
                isMuted: muted,
                volume: vol
            ))
        }

        let sorted = updatedProcesses.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let membershipChanged = (self._processes.map { $0.pid } != sorted.map { $0.pid })
        self._processes = sorted
        let listeners = self._changeListeners
        lock.unlock()

        for tap in tapsToInvalidate {
            tap.invalidate()
        }

        for tap in tapsToActivate {
            try? tap.activate()
        }

        if membershipChanged {
            for listener in listeners {
                listener()
            }
        }
    }

    public func setVolume(_ volume: Float, forPID pid: pid_t) throws {
        let clamped = min(max(volume, 0.0), 1.0)
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
        lock.unlock()

        tap?.setVolume(clamped)
        if let bundleID = bundleID {
            settingsManager.saveAppVolume(clamped, forBundleID: bundleID)
        }
    }

    public func toggleMute(forPID pid: pid_t) throws {
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
        lock.unlock()

        tap?.setMuted(newMuted)
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
        var tapsToActivate: [(pid: pid_t, objIDs: [AudioObjectID], volume: Float, uid: String)] = []
        var tapsToInvalidate: [ProcessTapController] = []
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
                    tapsToActivate.append((pid: proc.pid, objIDs: proc.objectIDs, volume: proc.volume, uid: newUID))
                }
            }
        } else {
            tapsToInvalidate = Array(_activeTaps.values)
            _activeTaps.removeAll()
        }
        listeners = _changeListeners
        lock.unlock()

        for tap in tapsToInvalidate {
            tap.invalidate()
        }

        for item in tapsToRecreate {
            try? item.tap.recreate(newOutputUID: item.uid)
        }

        for item in tapsToActivate {
            let tap = ProcessTapController(
                pid: item.pid,
                processObjectIDs: item.objIDs,
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
