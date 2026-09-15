import AppKit
import SoundLabCore

@MainActor
public final class PreferencesWindowController: NSWindowController {
    public init(settingsManager: SettingsManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SoundLab Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = GeneralPreferencesViewController(settingsManager: settingsManager)

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
