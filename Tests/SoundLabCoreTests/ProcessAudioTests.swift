import CoreAudio
import Foundation
import Testing
@testable import SoundLabCore

@Suite struct ProcessAudioTests {
    @Test func testAudioProcessModelInitializationAndEquality() {
        let process1 = AudioProcess(
            pid: 1234,
            objectID: 100,
            bundleID: "com.spotify.client",
            name: "Spotify",
            isMuted: false,
            volume: 0.8
        )
        let process2 = AudioProcess(
            pid: 1234,
            objectID: 100,
            bundleID: "com.spotify.client",
            name: "Spotify",
            isMuted: false,
            volume: 0.8
        )
        let process3 = AudioProcess(
            pid: 5678,
            objectID: 101,
            bundleID: "com.apple.Music",
            name: "Music"
        )
        let process4 = AudioProcess(
            pid: 9999,
            objectID: 102,
            name: "UnknownApp"
        )

        #expect(process1.id == 1234)
        #expect(process1.pid == 1234)
        #expect(process1.objectID == 100)
        #expect(process1.bundleID == "com.spotify.client")
        #expect(process1.name == "Spotify")
        #expect(process1.isMuted == false)
        #expect(process1.volume == 0.8)

        #expect(process3.bundleID == "com.apple.Music")
        #expect(process3.isMuted == false)
        #expect(process3.volume == 1.0)

        #expect(process4.bundleID == nil)
        #expect(process4.isMuted == false)
        #expect(process4.volume == 1.0)

        #expect(process1 == process2)
        #expect(process1 != process3)
        #expect(process1.hashValue == process2.hashValue)

        var mutableProcess = process1
        mutableProcess.volume = 0.5
        mutableProcess.isMuted = true
        #expect(mutableProcess.volume == 0.5)
        #expect(mutableProcess.isMuted == true)
        #expect(mutableProcess != process1)
    }

    @available(macOS 14.2, *)
    @Test func testMockProcessTapServiceProcessManagement() throws {
        let mock = MockProcessTapService()
        mock.addProcess(pid: 4001, objectID: 501)
        mock.addProcess(pid: 4002, objectID: 502)

        let objectIDs = try mock.getAudioProcessObjectIDs()
        #expect(objectIDs.contains(501))
        #expect(objectIDs.contains(502))
        #expect(objectIDs.count == 2)

        #expect(try mock.getPID(for: 501) == 4001)
        #expect(try mock.getProcessObjectID(for: 4002) == 502)

        mock.removeProcess(pid: 4001)
        #expect(try mock.getAudioProcessObjectIDs() == [502])

        #expect(throws: SoundLabAudioError.self) {
            _ = try mock.getPID(for: 501)
        }
        #expect(throws: SoundLabAudioError.self) {
            _ = try mock.getProcessObjectID(for: 4001)
        }

        mock.removeProcess(objectID: 502)
        #expect(try mock.getAudioProcessObjectIDs().isEmpty)
    }

    @available(macOS 14.2, *)
    @Test func testMockProcessTapServiceTapAndAggregateLifecycle() throws {
        let mock = MockProcessTapService()
        let tapUUID = UUID()

        let tapID = try mock.createProcessTap(for: 700, tapUUID: tapUUID)
        #expect(mock.createdTaps[tapID]?.tapUUID == tapUUID)
        #expect(mock.createdTaps[tapID]?.processObjectID == 700)

        try mock.destroyProcessTap(tapID)
        #expect(mock.destroyedTapIDs.contains(tapID))
        #expect(mock.createdTaps[tapID] == nil)

        #expect(throws: SoundLabAudioError.self) {
            try mock.destroyProcessTap(tapID)
        }

        let description: [String: Any] = ["mockKey": "mockVal"]
        let aggregateID = try mock.createAggregateDevice(description: description as CFDictionary)
        #expect(mock.createdAggregateDevices[aggregateID] != nil)

        try mock.destroyAggregateDevice(aggregateID)
        #expect(mock.destroyedAggregateIDs.contains(aggregateID))
        #expect(mock.createdAggregateDevices[aggregateID] == nil)

        #expect(throws: SoundLabAudioError.self) {
            try mock.destroyAggregateDevice(aggregateID)
        }
    }

    @available(macOS 14.2, *)
    @Test func testMockProcessTapServiceIOProcAndSimulation() throws {
        let mock = MockProcessTapService()
        let aggregateID: AudioObjectID = 3001

        final class FlagBox: @unchecked Sendable {
            var executed = false
        }
        let box = FlagBox()
        let ioBlock: ProcessTapIOBlock = { _, _, _, _, _ in
            box.executed = true
        }

        let procID = try mock.createIOProc(aggregateID: aggregateID, block: ioBlock)
        #expect(mock.registeredIOBlocks[aggregateID] != nil)

        try mock.startIO(aggregateID: aggregateID, procID: procID)
        #expect(mock.runningIOAggregateIDs.contains(aggregateID))

        var now = AudioTimeStamp()
        var inBuffer = AudioBufferList()
        var inTime = AudioTimeStamp()
        var outBuffer = AudioBufferList()
        var outTime = AudioTimeStamp()

        withUnsafePointer(to: &now) { nowPtr in
            withUnsafePointer(to: &inBuffer) { inBufPtr in
                withUnsafePointer(to: &inTime) { inTimePtr in
                    withUnsafeMutablePointer(to: &outBuffer) { outBufPtr in
                        withUnsafePointer(to: &outTime) { outTimePtr in
                            mock.simulateIO(
                                aggregateID: aggregateID,
                                inNow: nowPtr,
                                inInputData: inBufPtr,
                                inInputTime: inTimePtr,
                                outOutputData: outBufPtr,
                                inOutputTime: outTimePtr
                            )
                        }
                    }
                }
            }
        }
        #expect(box.executed == true)

        try mock.stopIO(aggregateID: aggregateID, procID: procID)
        #expect(!mock.runningIOAggregateIDs.contains(aggregateID))

        try mock.destroyIOProc(aggregateID: aggregateID, procID: procID)
        #expect(mock.destroyedIOProcAggregateIDs.contains(aggregateID))
        #expect(mock.registeredIOBlocks[aggregateID] == nil)

        #expect(throws: SoundLabAudioError.self) {
            try mock.destroyIOProc(aggregateID: aggregateID, procID: procID)
        }
    }

    @available(macOS 14.2, *)
    @Test func testMockProcessTapServiceErrorInjectionAndReset() throws {
        let mock = MockProcessTapService()
        mock.addProcess(pid: 999, objectID: 999)
        mock.errorToThrow = SoundLabAudioError.halError(-1)

        #expect(throws: SoundLabAudioError.self) {
            _ = try mock.getAudioProcessObjectIDs()
        }
        #expect(throws: SoundLabAudioError.self) {
            _ = try mock.createProcessTap(for: 999, tapUUID: UUID())
        }

        mock.reset()
        #expect(mock.errorToThrow == nil)
        #expect(try mock.getAudioProcessObjectIDs().isEmpty)
    }

    @available(macOS 14.2, *)
    @Test func testCoreAudioProcessTapServiceLiveHAL() throws {
        let service = CoreAudioProcessTapService()
        let objectIDs = try service.getAudioProcessObjectIDs()
        #expect(objectIDs.count >= 0)

        if let first = objectIDs.first {
            let pid = try service.getPID(for: first)
            #expect(pid > 0)

            let translatedID = try service.getProcessObjectID(for: pid)
            #expect(translatedID == first)
        }

        #expect(throws: SoundLabAudioError.self) {
            _ = try service.getProcessObjectID(for: 99_999_999)
        }
    }

    @available(macOS 14.2, *)
    @Test func testCoreAudioProcessTapServiceInvalidOperations() throws {
        let service = CoreAudioProcessTapService()

        #expect(throws: SoundLabAudioError.self) {
            _ = try service.getPID(for: 0xDEADBEEF)
        }

        #expect(throws: SoundLabAudioError.self) {
            let emptyDesc: [String: Any] = [:]
            _ = try service.createAggregateDevice(description: emptyDesc as CFDictionary)
        }

        #expect(throws: SoundLabAudioError.self) {
            _ = try service.createIOProc(aggregateID: 0xDEADBEEF) { _, _, _, _, _ in }
        }
    }
}
