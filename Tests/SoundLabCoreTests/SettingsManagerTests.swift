import Testing
import Foundation
@testable import SoundLabCore

@Suite struct SettingsManagerTests {
    @Test func testVolumePersistence() {
        let suiteName = "com.soundlab.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.getSavedVolume(for: "test-uid-1") == nil)

        settings.saveVolume(0.75, for: "test-uid-1")
        #expect(settings.getSavedVolume(for: "test-uid-1") == 0.75)

        settings.saveVolume(0.20, for: "test-uid-1")
        #expect(settings.getSavedVolume(for: "test-uid-1") == 0.20)
    }

    @Test func testVolumeClampingAndRemoval() {
        let suiteName = "com.soundlab.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)

        settings.saveVolume(1.5, for: "test-uid-clamp")
        #expect(settings.getSavedVolume(for: "test-uid-clamp") == 1.0)

        settings.saveVolume(-0.5, for: "test-uid-clamp")
        #expect(settings.getSavedVolume(for: "test-uid-clamp") == 0.0)

        settings.removeSavedVolume(for: "test-uid-clamp")
        #expect(settings.getSavedVolume(for: "test-uid-clamp") == nil)

        // Test resetAllSavedVolumes
        settings.saveVolume(0.3, for: "uid-a")
        settings.saveVolume(0.7, for: "uid-b")
        #expect(settings.getSavedVolume(for: "uid-a") == 0.3)
        #expect(settings.getSavedVolume(for: "uid-b") == 0.7)

        settings.resetAllSavedVolumes()
        #expect(settings.getSavedVolume(for: "uid-a") == nil)
        #expect(settings.getSavedVolume(for: "uid-b") == nil)
    }

    @Test func testPreferencesDefaults() {
        let suiteName = "com.soundlab.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.showDeviceNameInMenuBar == false)
        #expect(settings.showNotificationBanner == true)
        #expect(settings.hotkeysEnabled == true)
        #expect(settings.launchAtLogin == false)

        settings.showDeviceNameInMenuBar = true
        #expect(settings.showDeviceNameInMenuBar == true)

        settings.showNotificationBanner = false
        #expect(settings.showNotificationBanner == false)

        settings.hotkeysEnabled = false
        #expect(settings.hotkeysEnabled == false)

        settings.launchAtLogin = true
        #expect(settings.launchAtLogin == true)
    }

    @Test func testAppearanceModePersistence() {
        let suiteName = "app-test-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.appearanceMode == .system)

        settings.appearanceMode = .dark
        #expect(settings.appearanceMode == .dark)

        settings.appearanceMode = .light
        #expect(settings.appearanceMode == .light)
    }

    @Test func testAppVolumePersistence() {
        let suiteName = "app-vol-\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == nil)

        settings.saveAppVolume(0.65, forBundleID: "com.spotify.client")
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == 0.65)

        settings.saveAppVolume(1.5, forBundleID: "com.spotify.client")
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == 1.0)

        settings.saveAppVolume(-0.5, forBundleID: "com.spotify.client")
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == 0.0)

        settings.removeAppVolume(forBundleID: "com.spotify.client")
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == nil)
    }
}
