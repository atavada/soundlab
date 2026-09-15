import CoreAudio
import Foundation

public final class VolumeManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let settingsManager: SettingsManager
    private let lock = NSLock()
    private var volumeChangeCallbacks: [@Sendable (Float) -> Void] = []

    public init(hardwareService: AudioHardwareServiceProtocol, settingsManager: SettingsManager) {
        self.hardwareService = hardwareService
        self.settingsManager = settingsManager
    }

    public func getOutputVolume() throws -> Float {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        return try hardwareService.getVolume(for: defaultID, scope: .output)
    }

    public func setOutputVolume(_ volume: Float) throws {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        let clamped = min(max(volume, 0.0), 1.0)
        try hardwareService.setVolume(clamped, for: defaultID, scope: .output)

        if let uid = try? hardwareService.getDeviceUID(for: defaultID) {
            settingsManager.saveVolume(clamped, for: uid)
        }

        notifyVolumeChange(clamped)
    }

    public func restoreVolume(for deviceUID: String, deviceID: AudioDeviceID) throws {
        if let savedVolume = settingsManager.getSavedVolume(for: deviceUID) {
            try hardwareService.setVolume(savedVolume, for: deviceID, scope: .output)
            notifyVolumeChange(savedVolume)
        } else {
            // Save initial volume as baseline
            if let currentVolume = try? hardwareService.getVolume(for: deviceID, scope: .output) {
                settingsManager.saveVolume(currentVolume, for: deviceUID)
            }
        }
    }

    public func addVolumeChangeObserver(callback: @escaping @Sendable (Float) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        volumeChangeCallbacks.append(callback)
    }

    private func notifyVolumeChange(_ volume: Float) {
        lock.lock()
        let callbacks = volumeChangeCallbacks
        lock.unlock()
        for callback in callbacks {
            callback(volume)
        }
    }
}
