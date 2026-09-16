import AppKit
import SoundLabCore

@MainActor
private final class AppVolumeContainerView: NSView {
    weak var slider: NSSlider?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let slider = slider as? SteppingSlider, slider.performKeyEquivalent(with: event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if let slider = slider as? SteppingSlider, slider.performKeyEquivalent(with: event) {
            return
        }
        super.keyDown(with: event)
    }
}

@available(macOS 14.2, *)
@MainActor
public final class AppVolumeMenuItem: NSMenuItem, @unchecked Sendable {
    public private(set) var process: AudioProcess
    private weak var mixer: ProcessAudioMixer?

    let iconView = NSImageView()
    let titleLabel = NSTextField(labelWithString: "")
    let slider = SteppingSlider()
    let percentageLabel = NSTextField(labelWithString: "100%")
    let muteButton = NSButton()

    public init(process: AudioProcess, mixer: ProcessAudioMixer) {
        self.process = process
        self.mixer = mixer
        super.init(title: "", action: nil, keyEquivalent: "")

        setupView()
        update(process: process)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let container = AppVolumeContainerView(frame: NSRect(x: 0, y: 0, width: 280, height: 32))
        container.slider = slider

        iconView.frame = NSRect(x: 14, y: 8, width: 16, height: 16)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        updateAppIcon()

        titleLabel.frame = NSRect(x: 34, y: 7, width: 70, height: 18)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .labelColor

        slider.frame = NSRect(x: 108, y: 6, width: 90, height: 20)
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.isContinuous = true
        slider.refusesFirstResponder = false
        slider.target = self
        slider.action = #selector(sliderMoved(_:))

        percentageLabel.frame = NSRect(x: 202, y: 7, width: 36, height: 18)
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentageLabel.textColor = .secondaryLabelColor
        percentageLabel.alignment = .right
        percentageLabel.isEditable = false
        percentageLabel.isBordered = false
        percentageLabel.backgroundColor = .clear

        muteButton.frame = NSRect(x: 244, y: 7, width: 20, height: 18)
        muteButton.isBordered = false
        muteButton.bezelStyle = .regularSquare
        muteButton.imagePosition = .imageOnly
        muteButton.imageScaling = .scaleProportionallyDown
        muteButton.target = self
        muteButton.action = #selector(muteButtonClicked(_:))

        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(slider)
        container.addSubview(percentageLabel)
        container.addSubview(muteButton)

        self.view = container
    }

    public func update(process: AudioProcess) {
        self.process = process
        slider.floatValue = process.volume
        percentageLabel.stringValue = "\(Int(round(process.volume * 100)))%"
        let truncatedName = process.name.count > 12 ? String(process.name.prefix(12)) + "…" : process.name
        titleLabel.stringValue = truncatedName
        titleLabel.toolTip = process.name
        updateAppIcon()
        updateMuteButton()
    }

    private func updateAppIcon() {
        if let runningApp = NSRunningApplication(processIdentifier: process.pid),
           let icon = runningApp.icon {
            iconView.image = icon
        } else {
            iconView.image = NSImage(systemSymbolName: "app.fill", accessibilityDescription: process.name)
        }
    }

    private func updateMuteButton() {
        let symbolName = process.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: process.isMuted ? "Unmute" : "Mute")
        muteButton.contentTintColor = process.isMuted ? .systemRed : .secondaryLabelColor
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let val = sender.floatValue
        percentageLabel.stringValue = "\(Int(round(val * 100)))%"
        process.volume = val
        try? mixer?.setVolume(val, forPID: process.pid)
    }

    @objc private func muteButtonClicked(_ sender: NSButton) {
        do {
            try mixer?.toggleMute(forPID: process.pid)
            process.isMuted.toggle()
            updateMuteButton()
        } catch {
        }
    }
}
