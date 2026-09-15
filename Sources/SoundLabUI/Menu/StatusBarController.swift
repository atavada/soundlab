import AppKit
import SoundLabCore

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let deviceManager: DeviceManager
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    public var onOpenPreferences: (() -> Void)?

    public init(deviceManager: DeviceManager, volumeManager: VolumeManager, settingsManager: SettingsManager) {
        self.deviceManager = deviceManager
        self.volumeManager = volumeManager
        self.settingsManager = settingsManager
        super.init()
        setupStatusItem()
        rebuildMenu()

        deviceManager.addChangeListener { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
                self?.updateStatusItemTitle()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if #available(macOS 11.0, *) {
                let image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "SoundLab")
                image?.isTemplate = true
                button.image = image
            }
        }
        updateStatusItemTitle()
    }

    public func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        if settingsManager.showDeviceNameInMenuBar, let def = deviceManager.defaultOutputDevice {
            let maxLen = 14
            let truncated = def.name.count > maxLen ? "\(def.name.prefix(maxLen))…" : def.name
            button.title = " \(truncated)"
        } else {
            button.title = ""
        }
    }

    public func rebuildMenu() {
        statusItem?.menu = MenuBuilder.buildMenu(
            deviceManager: deviceManager,
            volumeManager: volumeManager,
            target: self,
            selectOutputAction: #selector(handleSelectOutput(_:)),
            selectInputAction: #selector(handleSelectInput(_:)),
            openPreferencesAction: #selector(handleOpenPreferences),
            quitAction: #selector(handleQuit)
        )
    }

    @objc private func handleSelectOutput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultOutput(deviceUID: uid)
        pulseStatusItem()
    }

    @objc private func handleSelectInput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultInput(deviceUID: uid)
        pulseStatusItem()
    }

    @objc private func handleOpenPreferences() {
        onOpenPreferences?()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    public func pulseStatusItem() {
        guard let button = statusItem?.button else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            button.alphaValue = 0.3
        }, completionHandler: {
            MainActor.assumeIsolated {
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.15
                    button.alphaValue = 1.0
                })
            }
        })
    }
}
