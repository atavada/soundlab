import CoreAudio

public enum SoundLabAudioError: Error, Equatable, Sendable {
    case deviceNotFound(id: AudioDeviceID)
    case deviceUIDNotFound(uid: String)
    case volumeNotSupported(id: AudioDeviceID)
    case halError(OSStatus)
    case propertyFetchFailed(String)
    case processNotFound(pid: pid_t)
    case processObjectIDNotFound(id: AudioObjectID)
    case tapNotFound(id: AudioObjectID)
    case aggregateDeviceNotFound(id: AudioObjectID)
    case ioProcNotFound
}
