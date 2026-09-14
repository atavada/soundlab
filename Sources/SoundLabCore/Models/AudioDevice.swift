import CoreAudio

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let scope: DeviceScope
    public let isDefault: Bool

    public init(id: AudioDeviceID, uid: String, name: String, scope: DeviceScope, isDefault: Bool = false) {
        self.id = id
        self.uid = uid
        self.name = name
        self.scope = scope
        self.isDefault = isDefault
    }

    public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id && lhs.uid == rhs.uid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(uid)
    }
}
