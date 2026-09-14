import Foundation

public final class SettingsManager: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    private enum Keys {
        static let volumePrefix = "soundlab.vol."
        static let launchAtLogin = "soundlab.launchAtLogin"
        static let showDeviceNameInMenuBar = "soundlab.showDeviceNameInMenuBar"
        static let showNotificationBanner = "soundlab.showNotificationBanner"
        static let hotkeysEnabled = "soundlab.hotkeysEnabled"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func getSavedVolume(for deviceUID: String) -> Float? {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.float(forKey: key)
    }

    public func saveVolume(_ volume: Float, for deviceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        userDefaults.set(min(max(volume, 0.0), 1.0), forKey: key)
    }

    public func removeSavedVolume(for deviceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        userDefaults.removeObject(forKey: key)
    }

    public var showDeviceNameInMenuBar: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: Keys.showDeviceNameInMenuBar)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.showDeviceNameInMenuBar)
        }
    }

    public var showNotificationBanner: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if userDefaults.object(forKey: Keys.showNotificationBanner) == nil {
                return true // default true
            }
            return userDefaults.bool(forKey: Keys.showNotificationBanner)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.showNotificationBanner)
        }
    }

    public var hotkeysEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if userDefaults.object(forKey: Keys.hotkeysEnabled) == nil {
                return true // default true
            }
            return userDefaults.bool(forKey: Keys.hotkeysEnabled)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.hotkeysEnabled)
        }
    }

    public var launchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }
}
