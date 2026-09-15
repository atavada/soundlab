// Sources/SoundLabApp/AppDelegate.swift
import AppKit
import SoundLabCore
import SoundLabUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hardwareService: CoreAudioHardwareService!
    private var settingsManager: SettingsManager!
    private var volumeManager: VolumeManager!
    private var deviceManager: DeviceManager!
    private var deviceObserver: DeviceObserver!
    private var notificationDispatcher: NotificationDispatcher!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: CarbonHotkeyManager!
    private var preferencesWindowController: PreferencesWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        settingsManager = SettingsManager()
        hardwareService = CoreAudioHardwareService()
        volumeManager = VolumeManager(hardwareService: hardwareService, settingsManager: settingsManager)
        deviceManager = DeviceManager(hardwareService: hardwareService, volumeManager: volumeManager, settingsManager: settingsManager)
        deviceObserver = DeviceObserver(hardwareService: hardwareService, deviceManager: deviceManager)
        notificationDispatcher = NotificationDispatcher(settingsManager: settingsManager)

        try? deviceManager.refreshDevices()
        deviceObserver.startObserving()

        statusBarController = StatusBarController(
            deviceManager: deviceManager,
            volumeManager: volumeManager,
            settingsManager: settingsManager
        )

        statusBarController.onOpenPreferences = { [weak self] in
            self?.openPreferences()
        }

        hotkeyManager = CarbonHotkeyManager(
            deviceManager: deviceManager,
            notificationDispatcher: notificationDispatcher,
            settingsManager: settingsManager
        )
        hotkeyManager.registerHotkeys()

        registerSleepWakeNotifications()
    }

    private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(settingsManager: settingsManager)
        }
        preferencesWindowController?.showPreferences()
    }

    private func registerSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                try? self?.deviceManager.refreshDevices()
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterHotkeys()
    }
}
