import CoreAudio
import Foundation

@available(macOS 14.2, *)
public final class CoreAudioProcessTapService: ProcessTapServiceProtocol, Sendable {
    public init() {}

    public func getAudioProcessObjectIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }

        var processObjectIDs = [AudioObjectID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &processObjectIDs
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return processObjectIDs
    }

    public func getPID(for processObjectID: AudioObjectID) throws -> pid_t {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var pid: pid_t = 0
        var dataSize = UInt32(MemoryLayout<pid_t>.size)

        let status = AudioObjectGetPropertyData(
            processObjectID,
            &address,
            0,
            nil,
            &dataSize,
            &pid
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return pid
    }

    public func getProcessObjectID(for pid: pid_t) throws -> AudioObjectID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyTranslatePIDToProcessObject,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var targetPID = pid
        let qualifierDataSize = UInt32(MemoryLayout<pid_t>.size)
        var processObjectID = AudioObjectID(kAudioObjectUnknown)
        var outDataSize = UInt32(MemoryLayout<AudioObjectID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            qualifierDataSize,
            &targetPID,
            &outDataSize,
            &processObjectID
        )
        guard status == noErr && processObjectID != AudioObjectID(kAudioObjectUnknown) else {
            throw SoundLabAudioError.processNotFound(pid: pid)
        }
        return processObjectID
    }

    public func createProcessTap(for processObjectID: AudioObjectID, tapUUID: UUID) throws -> AudioObjectID {
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDescription.uuid = tapUUID
        tapDescription.muteBehavior = .mutedWhenTapped

        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return tapID
    }

    public func destroyProcessTap(_ tapID: AudioObjectID) throws {
        let status = AudioHardwareDestroyProcessTap(tapID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func createAggregateDevice(description: CFDictionary) throws -> AudioObjectID {
        var aggregateID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(description, &aggregateID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return aggregateID
    }

    public func destroyAggregateDevice(_ aggregateID: AudioObjectID) throws {
        let status = AudioHardwareDestroyAggregateDevice(aggregateID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func createIOProc(aggregateID: AudioObjectID, block: @escaping ProcessTapIOBlock) throws -> AudioDeviceIOProcID {
        var procID: AudioDeviceIOProcID?
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            block(inNow, inInputData, inInputTime, outOutputData, inOutputTime)
        }
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        guard let id = procID else { throw SoundLabAudioError.ioProcNotFound }
        return id
    }

    public func destroyIOProc(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        let status = AudioDeviceDestroyIOProcID(aggregateID, procID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func startIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        let status = AudioDeviceStart(aggregateID, procID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func stopIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        let status = AudioDeviceStop(aggregateID, procID)
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }
}
