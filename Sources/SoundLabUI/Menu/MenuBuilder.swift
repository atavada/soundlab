import AppKit
import SoundLabCore

@MainActor
public final class MenuBuilder {
    public static func buildMenu(
        deviceManager: DeviceManager,
        volumeManager: VolumeManager,
        target: AnyObject,
        selectOutputAction: Selector,
        selectInputAction: Selector,
        openPreferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Section: Output Devices
        let outputHeader = NSMenuItem(title: "OUTPUT DEVICES", action: nil, keyEquivalent: "")
        outputHeader.isEnabled = false
        menu.addItem(outputHeader)

        for device in deviceManager.outputDevices {
            let item = NSMenuItem(title: device.name, action: selectOutputAction, keyEquivalent: "")
            item.target = target
            item.representedObject = device.uid
            item.state = device.isDefault ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Section: Output Volume Slider
        let sliderItem = VolumeSliderMenuItem(volumeManager: volumeManager)
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        // Section: Input Devices
        let inputHeader = NSMenuItem(title: "INPUT DEVICES", action: nil, keyEquivalent: "")
        inputHeader.isEnabled = false
        menu.addItem(inputHeader)

        for device in deviceManager.inputDevices {
            let item = NSMenuItem(title: device.name, action: selectInputAction, keyEquivalent: "")
            item.target = target
            item.representedObject = device.uid
            item.state = device.isDefault ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Section: Preferences & Quit
        let prefsItem = NSMenuItem(title: "Preferences…", action: openPreferencesAction, keyEquivalent: ",")
        prefsItem.target = target
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit SoundLab", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
