import CoreAudio
import Foundation

public typealias ProcessTapIOBlock = @Sendable (
    _ inNow: UnsafePointer<AudioTimeStamp>,
    _ inInputData: UnsafePointer<AudioBufferList>,
    _ inInputTime: UnsafePointer<AudioTimeStamp>,
    _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
    _ inOutputTime: UnsafePointer<AudioTimeStamp>
) -> Void

@available(macOS 14.2, *)
public protocol ProcessTapServiceProtocol: Sendable {
    func getAudioProcessObjectIDs() throws -> [AudioObjectID]
    func getPID(for processObjectID: AudioObjectID) throws -> pid_t
    func getProcessObjectID(for pid: pid_t) throws -> AudioObjectID
    func createProcessTap(for processObjectIDs: [AudioObjectID], tapUUID: UUID) throws -> AudioObjectID
    func destroyProcessTap(_ tapID: AudioObjectID) throws
    func createAggregateDevice(description: CFDictionary) throws -> AudioObjectID
    func destroyAggregateDevice(_ aggregateID: AudioObjectID) throws
    func createIOProc(aggregateID: AudioObjectID, block: @escaping ProcessTapIOBlock) throws -> AudioDeviceIOProcID
    func destroyIOProc(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws
    func startIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws
    func stopIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws
}

@available(macOS 14.2, *)
public extension ProcessTapServiceProtocol {
    func createProcessTap(for processObjectID: AudioObjectID, tapUUID: UUID) throws -> AudioObjectID {
        try createProcessTap(for: [processObjectID], tapUUID: tapUUID)
    }
}
