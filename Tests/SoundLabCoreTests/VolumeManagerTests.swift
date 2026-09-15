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
        volumeManager.addVolumeChangeObserver { vol in
            tracker.add(vol)
        }

        try volumeManager.setOutputVolume(0.7)
        try volumeManager.setOutputVolume(1.2) // clamps to 1.0

        #expect(tracker.get() == [0.7, 1.0])
    }
}
