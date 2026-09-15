// Sources/SoundLabUI/Hotkeys/CarbonHotkeyManager.swift
import Carbon
import Foundation
import SoundLabCore

public final class CarbonHotkeyManager: @unchecked Sendable {
    private weak var deviceManager: DeviceManager?
    private weak var notificationDispatcher: NotificationDispatcher?
    private let settingsManager: SettingsManager

    private var outputHotKeyRef: EventHotKeyRef?
    private var inputHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    nonisolated(unsafe) private static weak var sharedSelf: CarbonHotkeyManager?

    public init(deviceManager: DeviceManager, notificationDispatcher: NotificationDispatcher, settingsManager: SettingsManager) {
        self.deviceManager = deviceManager
        self.notificationDispatcher = notificationDispatcher
        self.settingsManager = settingsManager
    }

    public func registerHotkeys() {
        guard settingsManager.hotkeysEnabled else { return }
        Self.sharedSelf = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                if hotKeyID.id == 1 {
                    CarbonHotkeyManager.sharedSelf?.handleCycleOutput()
                } else if hotKeyID.id == 2 {
                    CarbonHotkeyManager.sharedSelf?.handleCycleInput()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Hotkey 1: Control + Option + Command + Space (Output)
        // Carbon modifier keys: controlKey (4096), optionKey (2048), cmdKey (256)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let spaceKeyCode = UInt32(kVK_Space)
        let outputID = EventHotKeyID(signature: OSType(0x534C4F55), id: 1) // 'SLOU'
        RegisterEventHotKey(spaceKeyCode, modifiers, outputID, GetApplicationEventTarget(), 0, &outputHotKeyRef)

        // Hotkey 2: Control + Option + Command + Down Arrow (Input)
        let downArrowKeyCode = UInt32(kVK_DownArrow)
        let inputID = EventHotKeyID(signature: OSType(0x534C494E), id: 2) // 'SLIN'
        RegisterEventHotKey(downArrowKeyCode, modifiers, inputID, GetApplicationEventTarget(), 0, &inputHotKeyRef)
    }

    private func handleCycleOutput() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            try? self.deviceManager?.cycleNextOutputDevice()
            if let def = self.deviceManager?.defaultOutputDevice {
                self.notificationDispatcher?.notifyDeviceSwitched(to: def)
            }
        }
    }

    private func handleCycleInput() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            try? self.deviceManager?.cycleNextInputDevice()
            if let def = self.deviceManager?.defaultInputDevice {
                self.notificationDispatcher?.notifyDeviceSwitched(to: def)
            }
        }
    }

    public func unregisterHotkeys() {
        if let ref = outputHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = inputHotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }

    deinit {
        unregisterHotkeys()
    }
}
