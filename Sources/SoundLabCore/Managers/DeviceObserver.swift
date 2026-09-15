// Sources/SoundLabCore/Managers/DeviceObserver.swift
import Foundation

public final class DeviceObserver: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private weak var deviceManager: DeviceManager?

    public init(hardwareService: AudioHardwareServiceProtocol, deviceManager: DeviceManager) {
        self.hardwareService = hardwareService
        self.deviceManager = deviceManager
    }

    public func startObserving() {
        try? hardwareService.addDeviceListChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }

        try? hardwareService.addDefaultDeviceChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }
    }
}
