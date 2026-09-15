import AppKit
import ServiceManagement
import SoundLabCore

@MainActor
public final class GeneralPreferencesViewController: NSViewController {
    private let settingsManager: SettingsManager
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch SoundLab at login", target: nil, action: nil)
    private let showTitleCheckbox = NSButton(checkboxWithTitle: "Show active device name in menu bar", target: nil, action: nil)
    private let notificationsCheckbox = NSButton(checkboxWithTitle: "Show banner notification on device switch", target: nil, action: nil)

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 160))

        let stack = NSStackView(views: [launchAtLoginCheckbox, showTitleCheckbox, notificationsCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])

        launchAtLoginCheckbox.state = settingsManager.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        showTitleCheckbox.state = settingsManager.showDeviceNameInMenuBar ? .on : .off
        showTitleCheckbox.target = self
        showTitleCheckbox.action = #selector(toggleShowTitle(_:))

        notificationsCheckbox.state = settingsManager.showNotificationBanner ? .on : .off
        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(toggleNotifications(_:))
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let isEnabled = (sender.state == .on)
        settingsManager.launchAtLogin = isEnabled

        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("SoundLab: Failed to update login item: \(error)")
            }
        }
    }

    @objc private func toggleShowTitle(_ sender: NSButton) {
        settingsManager.showDeviceNameInMenuBar = (sender.state == .on)
    }

    @objc private func toggleNotifications(_ sender: NSButton) {
        settingsManager.showNotificationBanner = (sender.state == .on)
    }
}
