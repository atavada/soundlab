import AppKit
import SoundLabCore

@MainActor
public final class PreferencesWindowController: NSWindowController {
    public init(settingsManager: SettingsManager, deviceManager: DeviceManager? = nil) {
        let tabViewController = NSTabViewController()
        tabViewController.tabStyle = .toolbar

        let generalVC = GeneralPreferencesViewController(settingsManager: settingsManager)
        let generalItem = NSTabViewItem(viewController: generalVC)
        generalItem.label = "General"
        if #available(macOS 11.0, *) {
            generalItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "General")
        }
        tabViewController.addTabViewItem(generalItem)

        let devicesVC = DevicesPreferencesViewController(settingsManager: settingsManager, deviceManager: deviceManager)
        let devicesItem = NSTabViewItem(viewController: devicesVC)
        devicesItem.label = "Devices"
        if #available(macOS 11.0, *) {
            devicesItem.image = NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: "Devices")
        }
        tabViewController.addTabViewItem(devicesItem)

        let shortcutsVC = ShortcutsPreferencesViewController(settingsManager: settingsManager)
        let shortcutsItem = NSTabViewItem(viewController: shortcutsVC)
        shortcutsItem.label = "Shortcuts"
        if #available(macOS 11.0, *) {
            shortcutsItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Shortcuts")
        }
        tabViewController.addTabViewItem(shortcutsItem)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SoundLab Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = tabViewController

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showPreferences() {
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
