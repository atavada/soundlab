import AppKit
import SoundLabCore

@MainActor
public final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let deviceManager: DeviceManager
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    private let notificationDispatcher: NotificationDispatcher
    private var processMixer: AnyObject?
    public var onOpenPreferences: (() -> Void)?

    public init(
        deviceManager: DeviceManager,
        volumeManager: VolumeManager,
        settingsManager: SettingsManager,
        notificationDispatcher: NotificationDispatcher,
        processMixer: AnyObject? = nil
    ) {
        self.deviceManager = deviceManager
        self.volumeManager = volumeManager
        self.settingsManager = settingsManager
        self.notificationDispatcher = notificationDispatcher
        self.processMixer = processMixer
        super.init()
        setupStatusItem()
        rebuildMenu()

        deviceManager.addChangeListener { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
                self?.updateStatusItemIcon()
                self?.updateStatusItemTitle()
            }
        }

        if #available(macOS 14.2, *) {
            if let mixer = processMixer as? ProcessAudioMixer {
                mixer.addChangeListener { [weak self] in
                    DispatchQueue.main.async {
                        self?.rebuildMenu()
                    }
                }
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.menu?.delegate = self
        updateStatusItemIcon()
        updateStatusItemTitle()
    }

    public func updateStatusItemIcon() {
        guard let button = statusItem?.button else { return }
        let symbolName: String
        if let def = deviceManager.defaultOutputDevice {
            let lower = def.name.lowercased()
            if lower.contains("headphone") ||
               lower.contains("airpods") ||
               lower.contains("buds") ||
               lower.contains("earphones") {
                symbolName = "headphones"
            } else {
                symbolName = "speaker.wave.2.fill"
            }
        } else {
            symbolName = "speaker.wave.2.fill"
        }

        if #available(macOS 11.0, *) {
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SoundLab")
            image?.isTemplate = true
            button.image = image
        }
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
        let menu = MenuBuilder.buildMenu(
            deviceManager: deviceManager,
            volumeManager: volumeManager,
            processMixer: processMixer,
            target: self,
            selectOutputAction: #selector(handleSelectOutput(_:)),
            selectInputAction: #selector(handleSelectInput(_:)),
            openPreferencesAction: #selector(handleOpenPreferences),
            quitAction: #selector(handleQuit)
        )
        menu.delegate = self
        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    public func menuWillOpen(_ menu: NSMenu) {
        if #available(macOS 14.2, *) {
            try? (processMixer as? ProcessAudioMixer)?.refreshAudioProcesses()
        }
    }

    @objc private func handleSelectOutput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultOutput(deviceUID: uid)
        if let device = deviceManager.outputDevices.first(where: { $0.uid == uid }) {
            notificationDispatcher.notifyDeviceSwitched(to: device)
        }
        pulseStatusItem()
    }

    @objc private func handleSelectInput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultInput(deviceUID: uid)
        if let device = deviceManager.inputDevices.first(where: { $0.uid == uid }) {
            notificationDispatcher.notifyDeviceSwitched(to: device)
        }
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
