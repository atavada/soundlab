// Sources/SoundLabCore/Managers/DeviceManager.swift
import CoreAudio
import Foundation

public final class DeviceManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    private let lock = NSLock()

    public private(set) var outputDevices: [AudioDevice] = []
    public private(set) var inputDevices: [AudioDevice] = []

    public var defaultOutputDevice: AudioDevice? {
        lock.lock()
        defer { lock.unlock() }
        return outputDevices.first { $0.isDefault }
    }

    public var defaultInputDevice: AudioDevice? {
        lock.lock()
        defer { lock.unlock() }
        return inputDevices.first { $0.isDefault }
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
        self.outputDevices = sortedOutputs
        self.inputDevices = sortedInputs
        let listeners = changeListeners
        lock.unlock()

        for listener in listeners {
            listener()
        }
    }

    public func setDefaultOutput(deviceUID: String) throws {
        lock.lock()
        guard let device = outputDevices.first(where: { $0.uid == deviceUID }) else {
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
        guard let device = inputDevices.first(where: { $0.uid == deviceUID }) else {
            lock.unlock()
            throw SoundLabAudioError.deviceUIDNotFound(uid: deviceUID)
        }
        lock.unlock()

        try hardwareService.setDefaultInputDevice(id: device.id)
        try refreshDevices()
    }

    public func cycleNextOutputDevice() throws {
        lock.lock()
        guard !outputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = outputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % outputDevices.count
        let nextDevice = outputDevices[nextIndex]
        lock.unlock()

        try setDefaultOutput(deviceUID: nextDevice.uid)
    }

    public func cycleNextInputDevice() throws {
        lock.lock()
        guard !inputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = inputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % inputDevices.count
        let nextDevice = inputDevices[nextIndex]
        lock.unlock()

        try setDefaultInput(deviceUID: nextDevice.uid)
    }

    public func addChangeListener(listener: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        changeListeners.append(listener)
    }
}
