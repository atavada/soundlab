import AppKit
import SoundLabCore

@MainActor
public final class DevicesPreferencesViewController: NSViewController {
    private let settingsManager: SettingsManager
    private weak var deviceManager: DeviceManager?

    private let outputLabel = NSTextField(labelWithString: "Output Devices:")
    private let outputDevicesText = NSTextField(wrappingLabelWithString: "")
    private let inputLabel = NSTextField(labelWithString: "Input Devices:")
    private let inputDevicesText = NSTextField(wrappingLabelWithString: "")
    private let resetButton = NSButton(title: "Reset Saved Volumes", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")

    public init(settingsManager: SettingsManager, deviceManager: DeviceManager? = nil) {
        self.settingsManager = settingsManager
        self.deviceManager = deviceManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 260))

        outputLabel.font = NSFont.boldSystemFont(ofSize: 12)
        inputLabel.font = NSFont.boldSystemFont(ofSize: 12)
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor

        resetButton.target = self
        resetButton.action = #selector(resetVolumesClicked(_:))
        resetButton.bezelStyle = .rounded

        let stack = NSStackView(views: [
            outputLabel,
            outputDevicesText,
            inputLabel,
            inputDevicesText,
            resetButton,
            statusLabel
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20)
        ])

        updateDeviceLists()

        deviceManager?.addChangeListener { [weak self] in
            DispatchQueue.main.async {
                self?.updateDeviceLists()
            }
        }
    }

    private func updateDeviceLists() {
        if let dm = deviceManager {
            let outputs = dm.outputDevices
            if outputs.isEmpty {
                outputDevicesText.stringValue = "No output devices found"
            } else {
                outputDevicesText.stringValue = outputs.map { dev in
                    dev.isDefault ? "• \(dev.name) (Default)" : "• \(dev.name)"
                }.joined(separator: "\n")
            }

            let inputs = dm.inputDevices
            if inputs.isEmpty {
                inputDevicesText.stringValue = "No input devices found"
            } else {
                inputDevicesText.stringValue = inputs.map { dev in
                    dev.isDefault ? "• \(dev.name) (Default)" : "• \(dev.name)"
                }.joined(separator: "\n")
            }
        } else {
            outputDevicesText.stringValue = "Device manager unavailable"
            inputDevicesText.stringValue = "Device manager unavailable"
        }
    }

    @objc private func resetVolumesClicked(_ sender: NSButton) {
        settingsManager.resetAllSavedVolumes()
        statusLabel.stringValue = "Saved device volumes have been reset."
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.statusLabel.stringValue = ""
        }
    }
}
