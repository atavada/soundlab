import Foundation
import UserNotifications
import SoundLabCore

public final class NotificationDispatcher: Sendable {
    private let settingsManager: SettingsManager

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func notifyDeviceSwitched(to device: AudioDevice) {
        guard settingsManager.showNotificationBanner else { return }

        let content = UNMutableNotificationContent()
        content.title = "Audio \(device.scope.displayName) Changed"
        content.body = "Active device: \(device.name)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "soundlab.switch.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
