import CoreAudio
import Foundation

public final class VolumeManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let settingsManager: SettingsManager
    private let lock = NSLock()
    private var volumeChangeCallbacks: [UUID: @Sendable (Float) -> Void] = [:]

    private var activeVolumeListenerToken: AudioHardwareListenerToken?
    private var defaultDeviceListenerToken: AudioListenerToken?
    private var activeDeviceID: AudioDeviceID?
    private var lastReportedVolume: Float?
    private var isSettingVolume: Bool = false

    public init(hardwareService: AudioHardwareServiceProtocol, settingsManager: SettingsManager) {
        self.hardwareService = hardwareService
        self.settingsManager = settingsManager

        startObserving()
    }

    public func getOutputVolume() throws -> Float {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        return try hardwareService.getVolume(for: defaultID, scope: .output)
    }

    public func setOutputVolume(_ volume: Float) throws {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        let clamped = min(max(volume, 0.0), 1.0)

        lock.lock()
        isSettingVolume = true
        lastReportedVolume = clamped
        lock.unlock()

        defer {
            lock.lock()
            isSettingVolume = false
            lock.unlock()
        }

        try hardwareService.setVolume(clamped, for: defaultID, scope: .output)

        if let uid = try? hardwareService.getDeviceUID(for: defaultID) {
            settingsManager.saveVolume(clamped, for: uid)
        }

        notifyVolumeChange(clamped)
    }

    public func restoreVolume(for deviceUID: String, deviceID: AudioDeviceID) throws {
        if let savedVolume = settingsManager.getSavedVolume(for: deviceUID) {
            lock.lock()
            isSettingVolume = true
            lastReportedVolume = savedVolume
            lock.unlock()

            defer {
                lock.lock()
                isSettingVolume = false
                lock.unlock()
            }

            try hardwareService.setVolume(savedVolume, for: deviceID, scope: .output)
            notifyVolumeChange(savedVolume)
        } else {
            // Save initial volume as baseline
            if let currentVolume = try? hardwareService.getVolume(for: deviceID, scope: .output) {
                lock.lock()
                lastReportedVolume = currentVolume
                lock.unlock()
                settingsManager.saveVolume(currentVolume, for: deviceUID)
            }
        }
    }

    @discardableResult
    public func addVolumeChangeObserver(callback: @escaping @Sendable (Float) -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        defer { lock.unlock() }
        volumeChangeCallbacks[id] = callback
        return id
    }

    public func removeVolumeChangeObserver(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        volumeChangeCallbacks.removeValue(forKey: id)
    }

    private func notifyVolumeChange(_ volume: Float) {
        lock.lock()
        let callbacks = Array(volumeChangeCallbacks.values)
        lock.unlock()
        for callback in callbacks {
            callback(volume)
        }
    }

    private func startObserving() {
        defaultDeviceListenerToken = try? hardwareService.addDefaultDeviceChangeListener { [weak self] in
            self?.handleDefaultDeviceChanged()
        }
        updateActiveDeviceVolumeListener()
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        if let token = activeVolumeListenerToken {
            hardwareService.removeVolumeChangeListener(token: token)
            activeVolumeListenerToken = nil
        }
        if let token = defaultDeviceListenerToken {
            try? hardwareService.removeDefaultDeviceChangeListener(token: token)
            defaultDeviceListenerToken = nil
        }
        activeDeviceID = nil
    }

    private func handleDefaultDeviceChanged() {
        lock.lock()
        defer { lock.unlock() }
        updateActiveDeviceVolumeListenerLocked()
    }

    private func updateActiveDeviceVolumeListener() {
        lock.lock()
        defer { lock.unlock() }
        updateActiveDeviceVolumeListenerLocked()
    }

    private func updateActiveDeviceVolumeListenerLocked() {
        if let token = activeVolumeListenerToken {
            hardwareService.removeVolumeChangeListener(token: token)
            activeVolumeListenerToken = nil
        }

        guard let defaultID = try? hardwareService.getDefaultOutputDeviceID(), defaultID != 0 else {
            activeDeviceID = nil
            lastReportedVolume = nil
            return
        }

        activeDeviceID = defaultID
        if let vol = try? hardwareService.getVolume(for: defaultID, scope: .output) {
            lastReportedVolume = vol
        } else {
            lastReportedVolume = nil
        }

        activeVolumeListenerToken = try? hardwareService.addVolumeChangeListener(deviceID: defaultID) { [weak self] in
            self?.handleHardwareVolumeChanged(deviceID: defaultID)
        }
    }

    private func handleHardwareVolumeChanged(deviceID: AudioDeviceID) {
        lock.lock()
        if isSettingVolume {
            lock.unlock()
            return
        }
        guard activeDeviceID == deviceID else {
            lock.unlock()
            return
        }
        guard let currentVolume = try? hardwareService.getVolume(for: deviceID, scope: .output) else {
            lock.unlock()
            return
        }
        if let last = lastReportedVolume, abs(last - currentVolume) < 0.001 {
            lock.unlock()
            return
        }
        lastReportedVolume = currentVolume
        lock.unlock()

        if let uid = try? hardwareService.getDeviceUID(for: deviceID) {
            settingsManager.saveVolume(currentVolume, for: uid)
        }

        notifyVolumeChange(currentVolume)
    }

    deinit {
        stopObserving()
    }
}
