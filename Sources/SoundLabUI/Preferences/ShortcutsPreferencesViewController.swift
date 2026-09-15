import AppKit
import SoundLabCore

@MainActor
public final class ShortcutsPreferencesViewController: NSViewController {
    private let settingsManager: SettingsManager
    private let enableHotkeysCheckbox = NSButton(checkboxWithTitle: "Enable global keyboard shortcuts", target: nil, action: nil)
    private let shortcutsHeaderLabel = NSTextField(labelWithString: "Configured Global Shortcuts:")
    private let outputShortcutLabel = NSTextField(labelWithString: "Cycle Output Device:  ⌃⌥⌘Space")
    private let inputShortcutLabel = NSTextField(labelWithString: "Cycle Input Device:   ⌃⌥⌘↓")
    private let noteLabel = NSTextField(wrappingLabelWithString: "Global hotkeys work from any application across macOS.")

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 220))

        shortcutsHeaderLabel.font = NSFont.boldSystemFont(ofSize: 12)
        outputShortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        inputShortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        noteLabel.font = NSFont.systemFont(ofSize: 11)
        noteLabel.textColor = .secondaryLabelColor

        enableHotkeysCheckbox.state = settingsManager.hotkeysEnabled ? .on : .off
        enableHotkeysCheckbox.target = self
        enableHotkeysCheckbox.action = #selector(toggleHotkeys(_:))

        let shortcutsBox = NSStackView(views: [
            shortcutsHeaderLabel,
            outputShortcutLabel,
            inputShortcutLabel,
            noteLabel
        ])
        shortcutsBox.orientation = .vertical
        shortcutsBox.alignment = .leading
        shortcutsBox.spacing = 8

        let mainStack = NSStackView(views: [
            enableHotkeysCheckbox,
            shortcutsBox
        ])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 16
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(mainStack)

        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])
    }

    @objc private func toggleHotkeys(_ sender: NSButton) {
        settingsManager.hotkeysEnabled = (sender.state == .on)
    }
}
