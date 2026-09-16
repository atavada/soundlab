import CoreAudio
import Foundation
import Testing
@testable import SoundLabCore

private final class StateBox<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

@Suite struct ProcessAudioMixerTests {

    @available(macOS 14.2, *)
    private func makeMixerFixture() throws -> (
        mixer: ProcessAudioMixer,
        mockTap: MockProcessTapService,
        mockHW: MockAudioHardwareService,
        deviceManager: DeviceManager,
        settings: SettingsManager,
        notificationCenter: NotificationCenter
    ) {
        let mockTap = MockProcessTapService()
        let mockHW = MockAudioHardwareService()
        mockHW.addMockDevice(id: 1, uid: "out-1", name: "Internal Speakers", scopes: [.output])
        mockHW.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mockHW.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "mixer-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mockHW, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mockHW, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        let notificationCenter = NotificationCenter()

        let appInfoProvider: ProcessAppInfoProvider = { pid in
            switch pid {
            case 1001: return (name: "Spotify", bundleID: "com.spotify.client")
            case 1002: return (name: "Safari", bundleID: "com.apple.Safari")
            case 1003: return (name: "QuickTime", bundleID: "com.apple.QuickTimePlayerX")
            default: return nil
            }
        }

        let mixer = ProcessAudioMixer(
            tapService: mockTap,
            deviceManager: deviceManager,
            settingsManager: settings,
            appInfoProvider: appInfoProvider,
            notificationCenter: notificationCenter
        )

        return (mixer, mockTap, mockHW, deviceManager, settings, notificationCenter)
    }

    // MARK: - Process Discovery & Tap Activation

    @available(macOS 14.2, *)
    @Test func testAudioProcessDiscoveryAndTapActivation() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let settings = fixture.settings

        // Pre-save Spotify volume in settings
        settings.saveAppVolume(0.65, forBundleID: "com.spotify.client")

        // Add 2 mock audio processes and self PID
        let selfPID = ProcessInfo.processInfo.processIdentifier
        mockTap.addProcess(pid: 1001, objectID: 50)
        mockTap.addProcess(pid: 1002, objectID: 51)
        mockTap.addProcess(pid: selfPID, objectID: 99)

        let listenerBox = StateBox(false)
        mixer.addChangeListener {
            listenerBox.value = true
        }

        try mixer.refreshAudioProcesses()

        #expect(listenerBox.value == true)

        // Self PID must be filtered out
        let processes = mixer.processes
        #expect(processes.count == 2)
        #expect(!processes.contains { $0.pid == selfPID })

        let spotify = processes.first { $0.pid == 1001 }
        let safari = processes.first { $0.pid == 1002 }

        #expect(spotify != nil)
        #expect(spotify?.name == "Spotify")
        #expect(spotify?.bundleID == "com.spotify.client")
        #expect(spotify?.volume == 0.65)
        #expect(spotify?.isMuted == false)

        #expect(safari != nil)
        #expect(safari?.name == "Safari")
        #expect(safari?.bundleID == "com.apple.Safari")
        #expect(safari?.volume == 1.0)
        #expect(safari?.isMuted == false)

        // Verify active taps created
        #expect(mixer.activeTaps.count == 2)
        let spotifyTap = mixer.activeTaps[1001]
        let safariTap = mixer.activeTaps[1002]

        #expect(spotifyTap != nil)
        #expect(spotifyTap?.isActive == true)
        #expect(spotifyTap?.volume == 0.65)
        #expect(spotifyTap?.outputUID == "out-1")

        #expect(safariTap != nil)
        #expect(safariTap?.isActive == true)
        #expect(safariTap?.volume == 1.0)
        #expect(safariTap?.outputUID == "out-1")

        #expect(mockTap.createdTaps.count == 2)
        #expect(mockTap.runningIOAggregateIDs.count == 2)
    }

    // MARK: - Volume Control & Persistence

    @available(macOS 14.2, *)
    @Test func testSetVolumeUpdatesTapAndSettings() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let settings = fixture.settings

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()

        let countBox = StateBox(0)
        mixer.addChangeListener {
            countBox.value += 1
        }

        try mixer.setVolume(0.42, forPID: 1001)

        // Sliders update locally without triggering menu rebuild listener
        #expect(countBox.value == 0)
        #expect(mixer.processes.first { $0.pid == 1001 }?.volume == 0.42)
        #expect(mixer.activeTaps[1001]?.volume == 0.42)
        #expect(mixer.activeTaps[1001]?.currentGain == 0.42)
        #expect(settings.getAppVolume(forBundleID: "com.spotify.client") == 0.42)

        // Setting volume for non-existent PID throws
        #expect(throws: SoundLabAudioError.self) {
            try mixer.setVolume(0.5, forPID: 9999)
        }
    }

    // MARK: - Mute Toggle

    @available(macOS 14.2, *)
    @Test func testToggleMuteUpdatesTapAndProcess() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()
        try mixer.setVolume(0.8, forPID: 1001)

        #expect(mixer.processes.first { $0.pid == 1001 }?.isMuted == false)
        #expect(mixer.activeTaps[1001]?.isMuted == false)
        #expect(mixer.activeTaps[1001]?.currentGain == 0.8)

        // Toggle mute ON
        try mixer.toggleMute(forPID: 1001)
        #expect(mixer.processes.first { $0.pid == 1001 }?.isMuted == true)
        #expect(mixer.activeTaps[1001]?.isMuted == true)
        #expect(mixer.activeTaps[1001]?.currentGain == 0.0)

        // Toggle mute OFF
        try mixer.toggleMute(forPID: 1001)
        #expect(mixer.processes.first { $0.pid == 1001 }?.isMuted == false)
        #expect(mixer.activeTaps[1001]?.isMuted == false)
        #expect(mixer.activeTaps[1001]?.currentGain == 0.8)

        // Non-existent PID throws
        #expect(throws: SoundLabAudioError.self) {
            try mixer.toggleMute(forPID: 9999)
        }
    }

    // MARK: - Output Device Reconciliation

    @available(macOS 14.2, *)
    @Test func testOutputDeviceChangeReconcilesActiveTaps() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let deviceManager = fixture.deviceManager

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()

        let tap = mixer.activeTaps[1001]
        let originalTapID = tap?.tapID
        let originalAggID = tap?.aggregateID
        #expect(tap?.outputUID == "out-1")

        // Switch default output device to out-2
        try deviceManager.setDefaultOutput(deviceUID: "out-2")

        #expect(mixer.activeTaps[1001]?.outputUID == "out-2")
        #expect(mixer.activeTaps[1001]?.tapID == originalTapID) // Tap ID preserved
        #expect(mixer.activeTaps[1001]?.aggregateID != originalAggID) // Agg ID recreated

        if let oldAggID = originalAggID {
            #expect(mockTap.destroyedAggregateIDs.contains(oldAggID))
        }
        if let newAggID = mixer.activeTaps[1001]?.aggregateID {
            #expect(mockTap.runningIOAggregateIDs.contains(newAggID))
        }
    }

    @available(macOS 14.2, *)
    @Test func testOutputDeviceDisappearingInvalidatesActiveTaps() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let mockHW = fixture.mockHW
        let deviceManager = fixture.deviceManager

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()

        #expect(mixer.activeTaps.count == 1)
        guard let tapID = mixer.activeTaps[1001]?.tapID else {
            Issue.record("Expected tapID for PID 1001")
            return
        }

        // Output disappears (unplugged)
        mockHW.devices.removeAll()
        mockHW.defaultOutputID = 0
        try deviceManager.refreshDevices()

        // Active taps must be invalidated and cleared
        #expect(mixer.activeTaps.isEmpty)
        #expect(mockTap.destroyedTapIDs.contains(tapID))
        #expect(mockTap.runningIOAggregateIDs.isEmpty)

        // Process models remain
        #expect(mixer.processes.count == 1)

        // Output reappears
        mockHW.addMockDevice(id: 1, uid: "out-restored", name: "Internal Speakers", scopes: [.output])
        mockHW.defaultOutputID = 1
        try deviceManager.refreshDevices()

        #expect(mixer.activeTaps.count == 1)
        #expect(mixer.activeTaps[1001]?.outputUID == "out-restored")
        #expect(mixer.activeTaps[1001]?.tapID != tapID)
        #expect(mockTap.destroyedTapIDs.contains(tapID))
        #expect(mockTap.createdTaps.count == 1)
    }

    // MARK: - Termination Teardown

    @available(macOS 14.2, *)
    @Test func testAppTerminationTeardownViaNotification() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let notificationCenter = fixture.notificationCenter

        mockTap.addProcess(pid: 1001, objectID: 50)
        mockTap.addProcess(pid: 1002, objectID: 51)
        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 2)
        #expect(mixer.activeTaps.count == 2)

        guard let tapID = mixer.activeTaps[1001]?.tapID else {
            Issue.record("Expected tapID for PID 1001")
            return
        }

        let listenerBox = StateBox(false)
        mixer.addChangeListener {
            listenerBox.value = true
        }

        // Post termination notification
        notificationCenter.post(
            name: ProcessAudioMixer.didTerminateApplicationNotification,
            object: nil as AnyObject?,
            userInfo: ["pid": pid_t(1001)]
        )

        #expect(listenerBox.value == true)
        #expect(mixer.processes.count == 1)
        #expect(mixer.processes.first?.pid == 1002)
        #expect(mixer.activeTaps[1001] == nil)
        #expect(mockTap.destroyedTapIDs.contains(tapID))
    }

    // MARK: - Process Disappearance In Refresh

    @available(macOS 14.2, *)
    @Test func testProcessDisappearanceInRefreshCleansUpTap() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap

        mockTap.addProcess(pid: 1001, objectID: 50)
        mockTap.addProcess(pid: 1002, objectID: 51)
        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 2)
        #expect(mixer.activeTaps.count == 2)
        let tapID1002 = mixer.activeTaps[1002]?.tapID

        // Remove PID 1002 from mock
        mockTap.removeProcess(pid: 1002)

        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 1)
        #expect(mixer.processes.first?.pid == 1001)
        #expect(mixer.activeTaps[1002] == nil)

        if let tapID = tapID1002 {
            #expect(mockTap.destroyedTapIDs.contains(tapID))
        }
    }

    // MARK: - Invalidation

    @available(macOS 14.2, *)
    @Test func testDirectProcessTerminationTeardown() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 1)
        #expect(mixer.activeTaps.count == 1)

        mixer.handleProcessTerminated(pid: 1001)

        #expect(mixer.processes.isEmpty)
        #expect(mixer.activeTaps.isEmpty)
    }

    @available(macOS 14.2, *)
    @Test func testAppTerminationWithNSNumberPIDNotification() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap
        let notificationCenter = fixture.notificationCenter

        mockTap.addProcess(pid: 1003, objectID: 52)
        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 1)

        notificationCenter.post(
            name: ProcessAudioMixer.didTerminateApplicationNotification,
            object: nil as AnyObject?,
            userInfo: ["NSApplicationProcessIdentifier": NSNumber(value: 1003)]
        )

        #expect(mixer.processes.isEmpty)
        #expect(mixer.activeTaps.isEmpty)
    }

    @available(macOS 14.2, *)
    @Test func testDelayedOutputDeviceActivatesPendingProcesses() throws {
        let mockTap = MockProcessTapService()
        let mockHW = MockAudioHardwareService()
        // Start with no output devices
        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "mixer-delayed-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mockHW, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mockHW, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        let mixer = ProcessAudioMixer(
            tapService: mockTap,
            deviceManager: deviceManager,
            settingsManager: settings,
            appInfoProvider: { _ in (name: "Spotify", bundleID: "com.spotify.client") }
        )

        mockTap.addProcess(pid: 1001, objectID: 50)
        try mixer.refreshAudioProcesses()

        #expect(mixer.processes.count == 1)
        #expect(mixer.activeTaps.isEmpty) // No output device yet!

        // Now output device becomes available
        mockHW.addMockDevice(id: 1, uid: "out-delayed", name: "Speakers", scopes: [.output])
        mockHW.defaultOutputID = 1
        try deviceManager.refreshDevices()

        #expect(mixer.activeTaps.count == 1)
        #expect(mixer.activeTaps[1001]?.outputUID == "out-delayed")
        #expect(mockTap.createdTaps.count == 1)
    }

    @available(macOS 14.2, *)
    @Test func testInvalidateTearsDownAllTaps() throws {
        let fixture = try makeMixerFixture()
        let mixer = fixture.mixer
        let mockTap = fixture.mockTap

        mockTap.addProcess(pid: 1001, objectID: 50)
        mockTap.addProcess(pid: 1002, objectID: 51)
        try mixer.refreshAudioProcesses()

        #expect(mixer.activeTaps.count == 2)

        mixer.invalidate()

        #expect(mixer.activeTaps.isEmpty)
        #expect(mixer.processes.isEmpty)
        #expect(mockTap.destroyedTapIDs.count == 2)
        #expect(mockTap.runningIOAggregateIDs.isEmpty)
    }

    @available(macOS 14.2, *)
    @Test func testDaemonAndDuplicateFiltering() throws {
        let mockTap = MockProcessTapService()
        let mockHW = MockAudioHardwareService()
        mockHW.addMockDevice(id: 1, uid: "out-1", name: "Internal Speakers", scopes: [.output])
        mockHW.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "mixer-filter-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mockHW, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mockHW, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        let appInfoProvider: ProcessAppInfoProvider = { pid in
            switch pid {
            case 2001: return (name: "Chrome Main", bundleID: "com.google.Chrome")
            case 2002: return (name: "Chrome Helper", bundleID: "com.google.Chrome") // duplicate bundle ID
            case 2003: return (name: "SoundLab", bundleID: "com.atavada.SoundLab") // self bundle ID
            case 2004: return (name: "   ", bundleID: "com.empty.name") // empty name
            default: return nil // background daemons without GUI app info
            }
        }

        let mixer = ProcessAudioMixer(
            tapService: mockTap,
            deviceManager: deviceManager,
            settingsManager: settings,
            appInfoProvider: appInfoProvider
        )

        mockTap.addProcess(pid: 2001, objectID: 60)
        mockTap.addProcess(pid: 2002, objectID: 61)
        mockTap.addProcess(pid: 2003, objectID: 62)
        mockTap.addProcess(pid: 2004, objectID: 63)
        mockTap.addProcess(pid: 9999, objectID: 64) // daemon (nil appInfo)

        try mixer.refreshAudioProcesses()

        // Only PID 2001 (Chrome Main) should be retained
        #expect(mixer.processes.count == 1)
        #expect(mixer.processes.first?.pid == 2001)
        #expect(mixer.processes.first?.name == "Chrome Main")
        #expect(mixer.activeTaps.count == 1)
        #expect(mixer.activeTaps[2001] != nil)
    }
}
