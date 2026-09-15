// Tests/SoundLabCoreTests/DeviceManagerTests.swift
import Testing
import Foundation
@testable import SoundLabCore

@Suite struct DeviceManagerTests {
    @Test func testEnumerateDevices() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.addMockDevice(id: 3, uid: "in-1", name: "Mic", scopes: [.input])
        mock.defaultOutputID = 1
        mock.defaultInputID = 3

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)

        try deviceManager.refreshDevices()

        let outputs = deviceManager.outputDevices
        let inputs = deviceManager.inputDevices

        #expect(outputs.count == 2)
        #expect(inputs.count == 1)
        #expect(outputs.first { $0.isDefault }?.uid == "out-1")
        #expect(inputs.first { $0.isDefault }?.uid == "in-1")
    }

    @Test func testSwitchDefaultOutputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        settings.saveVolume(0.8, for: "out-2")

        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.setDefaultOutput(deviceUID: "out-2")

        #expect(mock.defaultOutputID == 2)
        #expect(deviceManager.defaultOutputDevice?.uid == "out-2")
        #expect(try mock.getVolume(for: 2, scope: .output) == 0.8)
    }

    @Test func testCycleNextOutputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.cycleNextOutputDevice()
        #expect(mock.defaultOutputID == 2)

        try deviceManager.cycleNextOutputDevice()
        #expect(mock.defaultOutputID == 1) // Wraps around
    }

    @Test func testSwitchDefaultInputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 10, uid: "in-1", name: "Internal Mic", scopes: [.input])
        mock.addMockDevice(id: 20, uid: "in-2", name: "USB Mic", scopes: [.input])
        mock.defaultInputID = 10

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.setDefaultInput(deviceUID: "in-2")

        #expect(mock.defaultInputID == 20)
        #expect(deviceManager.defaultInputDevice?.uid == "in-2")
    }

    @Test func testCycleNextInputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 10, uid: "in-1", name: "Internal Mic", scopes: [.input])
        mock.addMockDevice(id: 20, uid: "in-2", name: "USB Mic", scopes: [.input])
        mock.defaultInputID = 10

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.cycleNextInputDevice()
        #expect(mock.defaultInputID == 20)

        try deviceManager.cycleNextInputDevice()
        #expect(mock.defaultInputID == 10)
    }

    @Test func testChangeListenerNotification() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)

        final class FlagTracker: @unchecked Sendable {
            var notified = false
            let lock = NSLock()
            func mark() {
                lock.lock()
                defer { lock.unlock() }
                notified = true
            }
            func isNotified() -> Bool {
                lock.lock()
                defer { lock.unlock() }
                return notified
            }
        }

        let tracker = FlagTracker()
        deviceManager.addChangeListener {
            tracker.mark()
        }

        try deviceManager.refreshDevices()
        #expect(tracker.isNotified())
    }

    @Test func testDeviceObserverStartObserving() async throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        let observer = DeviceObserver(hardwareService: mock, deviceManager: deviceManager)
        observer.startObserving()

        // Trigger change via mock
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.triggerDeviceListChange()

        // Wait for async main queue dispatch
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(deviceManager.outputDevices.count == 2)

        observer.stopObserving()
        mock.addMockDevice(id: 3, uid: "out-3", name: "AirPods", scopes: [.output])
        mock.triggerDeviceListChange()

        try await Task.sleep(nanoseconds: 50_000_000)
        // Device count should remain 2 because observer was stopped
        #expect(deviceManager.outputDevices.count == 2)
    }
}
