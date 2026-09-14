import CoreAudio

public enum DeviceScope: Sendable, Hashable, CaseIterable {
    case output
    case input
    case systemOutput

    public var displayName: String {
        switch self {
        case .output: return "Output"
        case .input: return "Input"
        case .systemOutput: return "System Output"
        }
    }

    public var audioObjectPropertyScope: AudioObjectPropertyScope {
        switch self {
        case .output, .systemOutput:
            return kAudioObjectPropertyScopeOutput
        case .input:
            return kAudioObjectPropertyScopeInput
        }
    }
}
