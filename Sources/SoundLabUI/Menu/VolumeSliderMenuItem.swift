import AppKit
import SoundLabCore

final class SteppingSlider: NSSlider {
    override func keyDown(with event: NSEvent) {
        if handleArrowKey(event) { return }
        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleArrowKey(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func handleArrowKey(_ event: NSEvent) -> Bool {
        let delta: Float
        switch event.keyCode {
        case 123, 125: // Left Arrow, Down Arrow
            delta = -0.05
        case 124, 126: // Right Arrow, Up Arrow
            delta = 0.05
        default:
            return false
        }

        let minVal = Float(minValue)
        let maxVal = Float(maxValue)
        let clamped = min(max(floatValue + delta, minVal), maxVal)
        floatValue = clamped
        if let action = action, let target = target {
            NSApp.sendAction(action, to: target, from: self)
        }
        return true
    }
}

private final class VolumeSliderContainerView: NSView {
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

@MainActor
public final class VolumeSliderMenuItem: NSMenuItem, @unchecked Sendable {
    private let slider = SteppingSlider()
    private let percentageLabel = NSTextField(labelWithString: "100%")
    private let iconView = NSImageView()
    private weak var volumeManager: VolumeManager?
    private var observerToken: UUID?

    public init(volumeManager: VolumeManager) {
        self.volumeManager = volumeManager
        super.init(title: "", action: nil, keyEquivalent: "")

        setupView()
        updateSliderPosition()

        self.observerToken = volumeManager.addVolumeChangeObserver { [weak self] vol in
            DispatchQueue.main.async {
                self?.slider.floatValue = vol
                self?.percentageLabel.stringValue = "\(Int(round(vol * 100)))%"
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let token = observerToken {
            volumeManager?.removeVolumeChangeObserver(id: token)
        }
    }

    private func setupView() {
        let container = VolumeSliderContainerView(frame: NSRect(x: 0, y: 0, width: 280, height: 32))
        container.slider = slider

        iconView.frame = NSRect(x: 14, y: 8, width: 16, height: 16)
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume")
        }

        slider.frame = NSRect(x: 36, y: 6, width: 185, height: 20)
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.isContinuous = true
        slider.refusesFirstResponder = false
        slider.target = self
        slider.action = #selector(sliderMoved(_:))

        percentageLabel.frame = NSRect(x: 226, y: 6, width: 40, height: 18)
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentageLabel.textColor = .secondaryLabelColor
        percentageLabel.alignment = .right

        container.addSubview(iconView)
        container.addSubview(slider)
        container.addSubview(percentageLabel)
        self.view = container
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let val = sender.floatValue
        percentageLabel.stringValue = "\(Int(round(val * 100)))%"
        try? volumeManager?.setOutputVolume(val)
    }

    private func updateSliderPosition() {
        if let currentVol = try? volumeManager?.getOutputVolume() {
            slider.floatValue = currentVol
            percentageLabel.stringValue = "\(Int(round(currentVol * 100)))%"
        }
    }
}
