import CoreAudio
import Foundation
@testable import SoundLabCore

@available(macOS 14.2, *)
public final class MockProcessTapService: ProcessTapServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    public struct TapRecord: Equatable, Sendable {
        public let tapID: AudioObjectID
        public let processObjectID: AudioObjectID
        public let tapUUID: UUID

        public init(tapID: AudioObjectID, processObjectID: AudioObjectID, tapUUID: UUID) {
            self.tapID = tapID
            self.processObjectID = processObjectID
            self.tapUUID = tapUUID
        }
    }

    public static let defaultMockIOProc: AudioDeviceIOProcID = { _, _, _, _, _, _, _ in 0 }

    public var processObjectIDs: [AudioObjectID] = []
    public var pidToObjectID: [pid_t: AudioObjectID] = [:]
    public var objectIDToPID: [AudioObjectID: pid_t] = [:]

    public var createdTaps: [AudioObjectID: TapRecord] = [:]
    public var destroyedTapIDs: [AudioObjectID] = []
    private var nextTapID: AudioObjectID = 1000

    public var createdAggregateDevices: [AudioObjectID: CFDictionary] = [:]
    public var destroyedAggregateIDs: [AudioObjectID] = []
    private var nextAggregateID: AudioObjectID = 2000

    public var registeredIOBlocks: [AudioObjectID: ProcessTapIOBlock] = [:]
    public var runningIOAggregateIDs: Set<AudioObjectID> = []
    public var destroyedIOProcAggregateIDs: [AudioObjectID] = []

    public var errorToThrow: Error?

    public init() {}

    // MARK: - ProcessTapServiceProtocol

    public func getAudioProcessObjectIDs() throws -> [AudioObjectID] {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        return processObjectIDs
    }

    public func getPID(for processObjectID: AudioObjectID) throws -> pid_t {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard let pid = objectIDToPID[processObjectID] else {
            throw SoundLabAudioError.processObjectIDNotFound(id: processObjectID)
        }
        return pid
    }

    public func getProcessObjectID(for pid: pid_t) throws -> AudioObjectID {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard let objID = pidToObjectID[pid] else {
            throw SoundLabAudioError.processNotFound(pid: pid)
        }
        return objID
    }

    public func createProcessTap(for processObjectID: AudioObjectID, tapUUID: UUID) throws -> AudioObjectID {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        let tapID = nextTapID
        nextTapID += 1
        let record = TapRecord(tapID: tapID, processObjectID: processObjectID, tapUUID: tapUUID)
        createdTaps[tapID] = record
        return tapID
    }

    public func destroyProcessTap(_ tapID: AudioObjectID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard createdTaps.removeValue(forKey: tapID) != nil else {
            throw SoundLabAudioError.tapNotFound(id: tapID)
        }
        destroyedTapIDs.append(tapID)
    }

    public func createAggregateDevice(description: CFDictionary) throws -> AudioObjectID {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        let aggregateID = nextAggregateID
        nextAggregateID += 1
        createdAggregateDevices[aggregateID] = description
        return aggregateID
    }

    public func destroyAggregateDevice(_ aggregateID: AudioObjectID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard createdAggregateDevices.removeValue(forKey: aggregateID) != nil else {
            throw SoundLabAudioError.aggregateDeviceNotFound(id: aggregateID)
        }
        destroyedAggregateIDs.append(aggregateID)
        runningIOAggregateIDs.remove(aggregateID)
        registeredIOBlocks.removeValue(forKey: aggregateID)
    }

    public func createIOProc(aggregateID: AudioObjectID, block: @escaping ProcessTapIOBlock) throws -> AudioDeviceIOProcID {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        registeredIOBlocks[aggregateID] = block
        return Self.defaultMockIOProc
    }

    public func destroyIOProc(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard registeredIOBlocks[aggregateID] != nil else {
            throw SoundLabAudioError.ioProcNotFound
        }
        registeredIOBlocks.removeValue(forKey: aggregateID)
        runningIOAggregateIDs.remove(aggregateID)
        destroyedIOProcAggregateIDs.append(aggregateID)
    }

    public func startIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        guard registeredIOBlocks[aggregateID] != nil else {
            throw SoundLabAudioError.ioProcNotFound
        }
        runningIOAggregateIDs.insert(aggregateID)
    }

    public func stopIO(aggregateID: AudioObjectID, procID: AudioDeviceIOProcID) throws {
        lock.lock()
        defer { lock.unlock() }
        if let error = errorToThrow { throw error }
        runningIOAggregateIDs.remove(aggregateID)
    }

    // MARK: - Simulation Helpers

    public func addProcess(pid: pid_t, objectID: AudioObjectID) {
        lock.lock()
        defer { lock.unlock() }
        pidToObjectID[pid] = objectID
        objectIDToPID[objectID] = pid
        if !processObjectIDs.contains(objectID) {
            processObjectIDs.append(objectID)
        }
    }

    public func removeProcess(pid: pid_t) {
        lock.lock()
        defer { lock.unlock() }
        if let objID = pidToObjectID.removeValue(forKey: pid) {
            objectIDToPID.removeValue(forKey: objID)
            processObjectIDs.removeAll { $0 == objID }
        }
    }

    public func removeProcess(objectID: AudioObjectID) {
        lock.lock()
        defer { lock.unlock() }
        if let pid = objectIDToPID.removeValue(forKey: objectID) {
            pidToObjectID.removeValue(forKey: pid)
            processObjectIDs.removeAll { $0 == objectID }
        }
    }

    public func simulateIO(
        aggregateID: AudioObjectID,
        inNow: UnsafePointer<AudioTimeStamp>,
        inInputData: UnsafePointer<AudioBufferList>,
        inInputTime: UnsafePointer<AudioTimeStamp>,
        outOutputData: UnsafeMutablePointer<AudioBufferList>,
        inOutputTime: UnsafePointer<AudioTimeStamp>
    ) {
        lock.lock()
        let block = registeredIOBlocks[aggregateID]
        lock.unlock()
        block?(inNow, inInputData, inInputTime, outOutputData, inOutputTime)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        processObjectIDs.removeAll()
        pidToObjectID.removeAll()
        objectIDToPID.removeAll()
        createdTaps.removeAll()
        destroyedTapIDs.removeAll()
        createdAggregateDevices.removeAll()
        destroyedAggregateIDs.removeAll()
        registeredIOBlocks.removeAll()
        runningIOAggregateIDs.removeAll()
        destroyedIOProcAggregateIDs.removeAll()
        errorToThrow = nil
    }
}
