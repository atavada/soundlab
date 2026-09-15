import AppKit
import SoundLabCore

@MainActor
public final class VolumeSliderMenuItem: NSMenuItem, @unchecked Sendable {
    private let slider = NSSlider()
    private let percentageLabel = NSTextField(labelWithString: "100%")
    private let iconView = NSImageView()
    private weak var volumeManager: VolumeManager?

    public init(volumeManager: VolumeManager) {
        self.volumeManager = volumeManager
        super.init(title: "", action: nil, keyEquivalent: "")

        setupView()
        updateSliderPosition()

        volumeManager.addVolumeChangeObserver { [weak self] vol in
            DispatchQueue.main.async {
                self?.slider.floatValue = vol
                self?.percentageLabel.stringValue = "\(Int(round(vol * 100)))%"
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 32))

        iconView.frame = NSRect(x: 14, y: 8, width: 16, height: 16)
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume")
        }

        slider.frame = NSRect(x: 36, y: 6, width: 125, height: 20)
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved(_:))

        percentageLabel.frame = NSRect(x: 168, y: 6, width: 45, height: 18)
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentageLabel.textColor = .secondaryLabelColor

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
