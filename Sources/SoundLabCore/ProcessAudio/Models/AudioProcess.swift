import CoreAudio
import Foundation

public struct AudioProcess: Identifiable, Hashable, Sendable {
    public let pid: pid_t
    public let objectIDs: [AudioObjectID]
    public let bundleID: String?
    public let name: String
    public var isMuted: Bool
    public var volume: Float

    public var objectID: AudioObjectID {
        objectIDs.first ?? 0
    }

    public var id: pid_t { pid }

    public init(
        pid: pid_t,
        objectIDs: [AudioObjectID],
        bundleID: String? = nil,
        name: String,
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.pid = pid
        self.objectIDs = objectIDs
        self.bundleID = bundleID
        self.name = name
        self.isMuted = isMuted
        self.volume = volume
    }

    public init(
        pid: pid_t,
        objectID: AudioObjectID,
        bundleID: String? = nil,
        name: String,
        isMuted: Bool = false,
        volume: Float = 1.0
    ) {
        self.init(
            pid: pid,
            objectIDs: [objectID],
            bundleID: bundleID,
            name: name,
            isMuted: isMuted,
            volume: volume
        )
    }
}
