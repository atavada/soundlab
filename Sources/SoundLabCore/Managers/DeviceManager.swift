// Sources/SoundLabCore/Managers/DeviceManager.swift
import CoreAudio
import Foundation

public final class DeviceManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    private let lock = NSLock()

    private var _outputDevices: [AudioDevice] = []
    private var _inputDevices: [AudioDevice] = []

    public var outputDevices: [AudioDevice] {
        lock.lock()
        defer { lock.unlock() }
        return _outputDevices
    }

    public var inputDevices: [AudioDevice] {
        lock.lock()
        defer { lock.unlock() }
        return _inputDevices
    }

    public var defaultOutputDevice: AudioDevice? {
        lock.lock()
        defer { lock.unlock() }
        return _outputDevices.first { $0.isDefault }
    }

    public var defaultInputDevice: AudioDevice? {
        lock.lock()
        defer { lock.unlock() }
        return _inputDevices.first { $0.isDefault }
    }

    private var changeListeners: [@Sendable () -> Void] = []

    public init(hardwareService: AudioHardwareServiceProtocol, volumeManager: VolumeManager, settingsManager: SettingsManager) {
        self.hardwareService = hardwareService
        self.volumeManager = volumeManager
        self.settingsManager = settingsManager
    }

    public func refreshDevices() throws {
        let allIDs = try hardwareService.getAllDeviceIDs()
        let defOutID = (try? hardwareService.getDefaultOutputDeviceID()) ?? 0
        let defInID = (try? hardwareService.getDefaultInputDeviceID()) ?? 0

        var newOutputs: [AudioDevice] = []
        var newInputs: [AudioDevice] = []

        for id in allIDs {
            guard let uid = try? hardwareService.getDeviceUID(for: id),
                  let name = try? hardwareService.getDeviceName(for: id),
                  let scopes = try? hardwareService.getDeviceScopes(for: id) else {
                continue
            }

            // Filter out internal SoundLab aggregate tap devices
            if uid.hasPrefix("SoundLab.") || name.hasPrefix("SoundLab-") {
                continue
            }

            if scopes.contains(.output) {
                let isDef = (id == defOutID)
                newOutputs.append(AudioDevice(id: id, uid: uid, name: name, scope: .output, isDefault: isDef))
            }

            if scopes.contains(.input) {
                let isDef = (id == defInID)
                newInputs.append(AudioDevice(id: id, uid: uid, name: name, scope: .input, isDefault: isDef))
            }
        }

        let sortedOutputs = newOutputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let sortedInputs = newInputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        lock.lock()
        self._outputDevices = sortedOutputs
        self._inputDevices = sortedInputs
        let listeners = changeListeners
        lock.unlock()

        for listener in listeners {
            listener()
        }
    }

    public func setDefaultOutput(deviceUID: String) throws {
        lock.lock()
        guard let device = _outputDevices.first(where: { $0.uid == deviceUID }) else {
            lock.unlock()
            throw SoundLabAudioError.deviceUIDNotFound(uid: deviceUID)
        }
        lock.unlock()

        try hardwareService.setDefaultOutputDevice(id: device.id)
        try volumeManager.restoreVolume(for: deviceUID, deviceID: device.id)
        try refreshDevices()
    }

    public func setDefaultInput(deviceUID: String) throws {
        lock.lock()
        guard let device = _inputDevices.first(where: { $0.uid == deviceUID }) else {
            lock.unlock()
            throw SoundLabAudioError.deviceUIDNotFound(uid: deviceUID)
        }
        lock.unlock()

        try hardwareService.setDefaultInputDevice(id: device.id)
        try refreshDevices()
    }

    public func cycleNextOutputDevice() throws {
        lock.lock()
        guard !_outputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = _outputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % _outputDevices.count
        let nextDevice = _outputDevices[nextIndex]
        lock.unlock()

        try setDefaultOutput(deviceUID: nextDevice.uid)
    }

    public func cycleNextInputDevice() throws {
        lock.lock()
        guard !_inputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = _inputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % _inputDevices.count
        let nextDevice = _inputDevices[nextIndex]
        lock.unlock()

        try setDefaultInput(deviceUID: nextDevice.uid)
    }

    public func addChangeListener(listener: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        changeListeners.append(listener)
    }
}
