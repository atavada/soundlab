import CoreAudio
import Foundation

public struct AudioProcess: Identifiable, Hashable, Sendable {
    public let pid: pid_t
    public let objectID: AudioObjectID
    public let bundleID: String?
    public let name: String
    public var isMuted: Bool
    public var volume: Float

    public var id: pid_t { pid }

    public init(
        pid: pid_t,
        objectID: AudioObjectID,
        bundleID: String? = nil,
        name: String,
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.pid = pid
        self.objectID = objectID
        self.bundleID = bundleID
        self.name = name
        self.isMuted = isMuted
        self.volume = volume
    }
}
