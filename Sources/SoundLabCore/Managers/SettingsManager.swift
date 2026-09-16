import Foundation

public enum AppearanceMode: String, Sendable, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    public var displayName: String {
        switch self {
        case .system: return "Follow System"
        case .dark: return "Dark Mode"
        case .light: return "Light Mode"
        }
    }
}

public final class SettingsManager: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    private enum Keys {
        static let volumePrefix = "soundlab.vol."
        static let appVolumePrefix = "soundlab.appvol."
        static let launchAtLogin = "soundlab.launchAtLogin"
        static let showDeviceNameInMenuBar = "soundlab.showDeviceNameInMenuBar"
        static let showNotificationBanner = "soundlab.showNotificationBanner"
        static let hotkeysEnabled = "soundlab.hotkeysEnabled"
        static let appearanceMode = "soundlab.appearanceMode"
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

    public func resetAllSavedVolumes() {
        lock.lock()
        defer { lock.unlock() }
        let dict = userDefaults.dictionaryRepresentation()
        for key in dict.keys where key.hasPrefix(Keys.volumePrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    public func getAppVolume(forBundleID bundleID: String) -> Float? {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.appVolumePrefix + bundleID
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.float(forKey: key)
    }

    public func saveAppVolume(_ volume: Float, forBundleID bundleID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.appVolumePrefix + bundleID
        userDefaults.set(min(max(volume, 0.0), 1.0), forKey: key)
    }

    public func removeAppVolume(forBundleID bundleID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.appVolumePrefix + bundleID
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

    public var appearanceMode: AppearanceMode {
        get {
            lock.lock()
            defer { lock.unlock() }
            guard let rawValue = userDefaults.string(forKey: Keys.appearanceMode),
                  let mode = AppearanceMode(rawValue: rawValue) else {
                return .system
            }
            return mode
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue.rawValue, forKey: Keys.appearanceMode)
        }
    }
}
