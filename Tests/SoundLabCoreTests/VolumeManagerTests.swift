import Testing
import Foundation
import CoreAudio
@testable import SoundLabCore

private extension MockAudioHardwareService {
    func addMockDevice(id: AudioDeviceID, uid: String, scopes: [DeviceScope], volume: Float = 0.5) {
        addMockDevice(id: id, uid: uid, name: uid, scopes: scopes, volume: volume)
    }
}

@Suite struct VolumeManagerTests {
    @Test func testGetAndSetOutputVolumeClamped() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", scopes: [.output], volume: 0.5)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        let vol = try volumeManager.getOutputVolume()
        #expect(vol == 0.5)

        try volumeManager.setOutputVolume(0.85)
        #expect(try volumeManager.getOutputVolume() == 0.85)
        #expect(settings.getSavedVolume(for: "dev-1") == 0.85)

        // Test upper clamp
        try volumeManager.setOutputVolume(1.5)
        #expect(try volumeManager.getOutputVolume() == 1.0)

        // Test lower clamp
        try volumeManager.setOutputVolume(-0.2)
        #expect(try volumeManager.getOutputVolume() == 0.0)
    }

    @Test func testRestoreSavedVolumeOnDeviceSwitch() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", scopes: [.output], volume: 0.3)
        mock.addMockDevice(id: 2, uid: "dev-2", scopes: [.output], volume: 0.9)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        settings.saveVolume(0.65, for: "dev-2")

        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        try volumeManager.restoreVolume(for: "dev-2", deviceID: 2)

        #expect(try mock.getVolume(for: 2, scope: .output) == 0.65)
    }

    @Test func testRestoreVolumeSavesBaselineWhenNotSaved() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 3, uid: "dev-3", scopes: [.output], volume: 0.42)
        mock.defaultOutputID = 3

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        #expect(settings.getSavedVolume(for: "dev-3") == nil)

        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        try volumeManager.restoreVolume(for: "dev-3", deviceID: 3)

        #expect(settings.getSavedVolume(for: "dev-3") == 0.42)
        #expect(try mock.getVolume(for: 3, scope: .output) == 0.42)
    }

    @Test func testVolumeChangeObserverNotification() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", scopes: [.output], volume: 0.5)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        final class CallbackTracker: @unchecked Sendable {
            var receivedVolumes: [Float] = []
            let lock = NSLock()
            func add(_ vol: Float) {
                lock.lock()
                defer { lock.unlock() }
                receivedVolumes.append(vol)
            }
            func get() -> [Float] {
                lock.lock()
                defer { lock.unlock() }
                return receivedVolumes
            }
        }

        let tracker = CallbackTracker()
        let token = volumeManager.addVolumeChangeObserver { vol in
            tracker.add(vol)
        }

        try volumeManager.setOutputVolume(0.7)
        try volumeManager.setOutputVolume(1.2) // clamps to 1.0

        #expect(tracker.get() == [0.7, 1.0])

        volumeManager.removeVolumeChangeObserver(id: token)
        try volumeManager.setOutputVolume(0.4)
        #expect(tracker.get() == [0.7, 1.0])
    }

    @Test func testExternalVolumeChangeSyncsObservers() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", name: "Speakers", scopes: [.output], volume: 0.5)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "ext-vol-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        final class VolumeBox: @unchecked Sendable {
            private let lock = NSLock()
            private var _value: Float = 0.0
            var value: Float {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _value
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _value = newValue
                }
            }
        }

        let box = VolumeBox()
        _ = volumeManager.addVolumeChangeObserver { vol in
            box.value = vol
        }

        // Trigger mock external hardware change
        try mock.setVolume(0.80, for: 1, scope: .output)
        mock.triggerVolumeChange(for: 1)

        #expect(box.value == 0.80)
        #expect(settings.getSavedVolume(for: "dev-1") == 0.80)
    }

    @Test func testFeedbackLoopPrevention() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", name: "Speakers", scopes: [.output], volume: 0.5)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "feedback-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        final class NotificationCounter: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _count
                }
            }
            func increment() {
                lock.lock()
                defer { lock.unlock() }
                _count += 1
            }
        }

        let counter = NotificationCounter()
        _ = volumeManager.addVolumeChangeObserver { _ in
            counter.increment()
        }

        try volumeManager.setOutputVolume(0.75)
        #expect(counter.count == 1)

        // Simulate CoreAudio firing hardware volume listener with the same volume
        mock.triggerVolumeChange(for: 1)
        #expect(counter.count == 1) // Should not fire a second time
    }

    @Test func testDefaultDeviceSwitchUpdatesVolumeListener() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", name: "Speakers", scopes: [.output], volume: 0.5)
        mock.addMockDevice(id: 2, uid: "dev-2", name: "Headphones", scopes: [.output], volume: 0.3)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "switch-listener-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        final class VolumeBox: @unchecked Sendable {
            private let lock = NSLock()
            private var _value: Float = 0.0
            var value: Float {
                get {
                    lock.lock()
                    defer { lock.unlock() }
                    return _value
                }
                set {
                    lock.lock()
                    defer { lock.unlock() }
                    _value = newValue
                }
            }
        }

        let box = VolumeBox()
        _ = volumeManager.addVolumeChangeObserver { vol in
            box.value = vol
        }

        // Switch default output device to 2
        try mock.setDefaultOutputDevice(id: 2)

        // Volume change on old device (1) should be ignored
        try mock.setVolume(0.99, for: 1, scope: .output)
        mock.triggerVolumeChange(for: 1)
        #expect(box.value == 0.0)

        // Volume change on new device (2) should be received
        try mock.setVolume(0.65, for: 2, scope: .output)
        mock.triggerVolumeChange(for: 2)
        #expect(box.value == 0.65)
        #expect(settings.getSavedVolume(for: "dev-2") == 0.65)
    }
}
