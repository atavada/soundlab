// Sources/SoundLabCore/Managers/DeviceObserver.swift
import Foundation

public final class DeviceObserver: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private weak var deviceManager: DeviceManager?
    private var listToken: AudioListenerToken?
    private var defaultToken: AudioListenerToken?
    private let lock = NSLock()

    public init(hardwareService: AudioHardwareServiceProtocol, deviceManager: DeviceManager) {
        self.hardwareService = hardwareService
        self.deviceManager = deviceManager
    }

    public func startObserving() {
        lock.lock()
        defer { lock.unlock() }
        stopObservingLocked()

        listToken = try? hardwareService.addDeviceListChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }

        defaultToken = try? hardwareService.addDefaultDeviceChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }
    }

    public func stopObserving() {
        lock.lock()
        defer { lock.unlock() }
        stopObservingLocked()
    }

    private func stopObservingLocked() {
        if let token = listToken {
            try? hardwareService.removeDeviceListChangeListener(token: token)
            listToken = nil
        }
        if let token = defaultToken {
            try? hardwareService.removeDefaultDeviceChangeListener(token: token)
            defaultToken = nil
        }
    }

    deinit {
        stopObserving()
    }
}
