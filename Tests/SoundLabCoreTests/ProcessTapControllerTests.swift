import CoreAudio
import Foundation
import Testing
@testable import SoundLabCore

@Suite struct ProcessTapControllerTests {

    // MARK: - DSP Buffer Processing Tests

    @available(macOS 14.2, *)
    @Test func testAudioBufferGainScaling() {
        var inSamples: [Float] = [1.0, -0.5, 0.25, 0.0]
        var outSamples: [Float] = [0.0, 0.0, 0.0, 0.0]

        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                ProcessTapController.processAudioBufferList(
                    input: UnsafePointer(inABL),
                    output: outABL,
                    volume: 0.5
                )
            }
        }

        #expect(inSamples == [1.0, -0.5, 0.25, 0.0])
        #expect(outSamples == [0.5, -0.25, 0.125, 0.0])
    }

    @available(macOS 14.2, *)
    @Test func testAudioBufferInPlaceScaling() {
        var samples: [Float] = [1.0, -0.5, 0.25, 0.0]

        withSingleBufferABL(samples: &samples) { abl in
            ProcessTapController.processAudioBufferList(
                input: UnsafePointer(abl),
                output: abl,
                volume: 0.5
            )
        }

        #expect(samples == [0.5, -0.25, 0.125, 0.0])
    }

    @available(macOS 14.2, *)
    @Test func testAudioBufferMuteScaling() {
        var inSamples: [Float] = [1.0, -0.5, 0.25, 0.0]
        var outSamples: [Float] = [9.0, 9.0, 9.0, 9.0]

        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                ProcessTapController.processAudioBufferList(
                    input: UnsafePointer(inABL),
                    output: outABL,
                    volume: 0.0
                )
            }
        }

        #expect(outSamples == [0.0, 0.0, 0.0, 0.0])
    }

    @available(macOS 14.2, *)
    @Test func testAudioBufferUnityGain() {
        var inSamples: [Float] = [1.0, -0.5, 0.25, 0.0]
        var outSamples: [Float] = [0.0, 0.0, 0.0, 0.0]

        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                ProcessTapController.processAudioBufferList(
                    input: UnsafePointer(inABL),
                    output: outABL,
                    volume: 1.0
                )
            }
        }

        #expect(outSamples == inSamples)
    }

    @available(macOS 14.2, *)
    @Test func testAudioBufferMultiChannelNonInterleavedScaling() {
        var inLeft: [Float] = [1.0, 0.5]
        var inRight: [Float] = [-1.0, -0.5]
        var outLeft: [Float] = [0.0, 0.0]
        var outRight: [Float] = [0.0, 0.0]

        withDualBufferABL(left: &inLeft, right: &inRight) { inABL in
            withDualBufferABL(left: &outLeft, right: &outRight) { outABL in
                ProcessTapController.processAudioBufferList(
                    input: UnsafePointer(inABL),
                    output: outABL,
                    volume: 0.5
                )
            }
        }

        #expect(outLeft == [0.5, 0.25])
        #expect(outRight == [-0.5, -0.25])
    }

    // MARK: - Volume & Mute Control Tests

    @available(macOS 14.2, *)
    @Test func testVolumeClamping() {
        let mock = MockProcessTapService()
        let controller = ProcessTapController(
            pid: 1234,
            processObjectID: 100,
            outputUID: "SpeakerUID",
            service: mock,
            initialVolume: 1.5
        )

        #expect(controller.volume == 1.0)
        #expect(controller.currentGain == 1.0)

        controller.setVolume(-0.5)
        #expect(controller.volume == 0.0)
        #expect(controller.currentGain == 0.0)

        controller.setVolume(2.0)
        #expect(controller.volume == 1.0)
        #expect(controller.currentGain == 1.0)

        controller.setVolume(0.75)
        #expect(controller.volume == 0.75)
        #expect(controller.currentGain == 0.75)
    }

    @available(macOS 14.2, *)
    @Test func testMuteAndUnmute() {
        let mock = MockProcessTapService()
        let controller = ProcessTapController(
            pid: 1234,
            processObjectID: 100,
            outputUID: "SpeakerUID",
            service: mock,
            initialVolume: 0.8
        )

        #expect(controller.volume == 0.8)
        #expect(controller.isMuted == false)
        #expect(controller.currentGain == 0.8)

        controller.setMuted(true)
        #expect(controller.volume == 0.8)
        #expect(controller.isMuted == true)
        #expect(controller.currentGain == 0.0)

        controller.setVolume(0.6)
        #expect(controller.volume == 0.6)
        #expect(controller.isMuted == true)
        #expect(controller.currentGain == 0.0)

        controller.setMuted(false)
        #expect(controller.volume == 0.6)
        #expect(controller.isMuted == false)
        #expect(controller.currentGain == 0.6)
    }

    // MARK: - Lifecycle Tests

    @available(macOS 14.2, *)
    @Test func testLifecycleActivationAndIOSimulation() throws {
        let mock = MockProcessTapService()
        let controller = ProcessTapController(
            pid: 5678,
            processObjectID: 200,
            outputUID: "BuiltInSpeakerDevice",
            service: mock,
            initialVolume: 0.5
        )

        #expect(controller.isActive == false)
        #expect(controller.tapID == nil)
        #expect(controller.aggregateID == nil)
        #expect(controller.procID == nil)

        try controller.activate()

        #expect(controller.isActive == true)
        #expect(controller.procID != nil)
        guard let tapID = controller.tapID,
              let aggregateID = controller.aggregateID else {
            Issue.record("Expected tapID, aggregateID to be set after activate()")
            return
        }

        #expect(mock.createdTaps[tapID] != nil)
        #expect(mock.createdTaps[tapID]?.processObjectID == 200)
        #expect(mock.createdAggregateDevices[aggregateID] != nil)
        #expect(mock.runningIOAggregateIDs.contains(aggregateID))

        // Verify aggregate device dictionary configuration
        if let desc = mock.createdAggregateDevices[aggregateID] as NSDictionary? {
            let mainSubDev = desc[kAudioAggregateDeviceMainSubDeviceKey] as? String
            #expect(mainSubDev == "BuiltInSpeakerDevice")
            let isPrivate = desc[kAudioAggregateDeviceIsPrivateKey] as? Bool
            #expect(isPrivate == true)
        } else {
            Issue.record("Expected aggregate device dictionary")
        }

        // Simulate IO callback execution
        var now = AudioTimeStamp()
        var inTime = AudioTimeStamp()
        var outTime = AudioTimeStamp()
        var inSamples: [Float] = [1.0, 0.5]
        var outSamples: [Float] = [0.0, 0.0]

        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                withUnsafePointer(to: &now) { nowPtr in
                    withUnsafePointer(to: &inTime) { inTimePtr in
                        withUnsafePointer(to: &outTime) { outTimePtr in
                            mock.simulateIO(
                                aggregateID: aggregateID,
                                inNow: nowPtr,
                                inInputData: UnsafePointer(inABL),
                                inInputTime: inTimePtr,
                                outOutputData: outABL,
                                inOutputTime: outTimePtr
                            )
                        }
                    }
                }
            }
        }
        #expect(outSamples == [0.5, 0.25])

        // Update volume and simulate IO again
        controller.setVolume(0.2)
        outSamples = [0.0, 0.0]
        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                withUnsafePointer(to: &now) { nowPtr in
                    withUnsafePointer(to: &inTime) { inTimePtr in
                        withUnsafePointer(to: &outTime) { outTimePtr in
                            mock.simulateIO(
                                aggregateID: aggregateID,
                                inNow: nowPtr,
                                inInputData: UnsafePointer(inABL),
                                inInputTime: inTimePtr,
                                outOutputData: outABL,
                                inOutputTime: outTimePtr
                            )
                        }
                    }
                }
            }
        }
        #expect(outSamples == [0.2, 0.1])

        // Mute and simulate IO
        controller.setMuted(true)
        outSamples = [9.0, 9.0]
        withSingleBufferABL(samples: &inSamples) { inABL in
            withSingleBufferABL(samples: &outSamples) { outABL in
                withUnsafePointer(to: &now) { nowPtr in
                    withUnsafePointer(to: &inTime) { inTimePtr in
                        withUnsafePointer(to: &outTime) { outTimePtr in
                            mock.simulateIO(
                                aggregateID: aggregateID,
                                inNow: nowPtr,
                                inInputData: UnsafePointer(inABL),
                                inInputTime: inTimePtr,
                                outOutputData: outABL,
                                inOutputTime: outTimePtr
                            )
                        }
                    }
                }
            }
        }
        #expect(outSamples == [0.0, 0.0])

        controller.invalidate()
        #expect(controller.isActive == false)
        #expect(mock.destroyedTapIDs.contains(tapID))
        #expect(mock.destroyedAggregateIDs.contains(aggregateID))
        #expect(mock.destroyedIOProcAggregateIDs.contains(aggregateID))
        #expect(!mock.runningIOAggregateIDs.contains(aggregateID))
    }

    @available(macOS 14.2, *)
    @Test func testRecreateOnDeviceSwitch() throws {
        let mock = MockProcessTapService()
        let controller = ProcessTapController(
            pid: 5678,
            processObjectID: 200,
            outputUID: "SpeakerUID",
            service: mock,
            initialVolume: 0.8
        )

        try controller.activate()
        guard let originalTapID = controller.tapID,
              let originalAggID = controller.aggregateID else {
            Issue.record("Expected tapID and aggregateID to be set after activate()")
            return
        }

        #expect(controller.outputUID == "SpeakerUID")

        try controller.recreate(newOutputUID: "HeadphonesUID")

        #expect(controller.outputUID == "HeadphonesUID")
        #expect(controller.tapID == originalTapID) // Tap retained!
        #expect(!mock.destroyedTapIDs.contains(originalTapID))

        #expect(mock.destroyedAggregateIDs.contains(originalAggID))
        #expect(mock.destroyedIOProcAggregateIDs.contains(originalAggID))

        guard let newAggID = controller.aggregateID else {
            Issue.record("Expected new aggregateID to be set after recreate()")
            return
        }
        #expect(newAggID != originalAggID)
        #expect(mock.runningIOAggregateIDs.contains(newAggID))

        if let desc = mock.createdAggregateDevices[newAggID] as NSDictionary? {
            let mainSubDev = desc[kAudioAggregateDeviceMainSubDeviceKey] as? String
            #expect(mainSubDev == "HeadphonesUID")
        } else {
            Issue.record("Expected new aggregate device dictionary")
        }
    }

    @available(macOS 14.2, *)
    @Test func testInvalidateIsIdempotent() throws {
        let mock = MockProcessTapService()
        let controller = ProcessTapController(
            pid: 5678,
            processObjectID: 200,
            outputUID: "SpeakerUID",
            service: mock
        )

        try controller.activate()
        #expect(controller.isActive == true)

        controller.invalidate()
        #expect(controller.isActive == false)

        // Multiple invalidations must not throw or crash
        controller.invalidate()
        #expect(controller.isActive == false)
    }

    // MARK: - Helpers

    private func withSingleBufferABL(
        samples: inout [Float],
        _ body: (UnsafeMutablePointer<AudioBufferList>) -> Void
    ) {
        samples.withUnsafeMutableBytes { rawBytes in
            let buffer = AudioBuffer(
                mNumberChannels: 2,
                mDataByteSize: UInt32(rawBytes.count),
                mData: rawBytes.baseAddress
            )
            var abl = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: buffer
            )
            withUnsafeMutablePointer(to: &abl) { ablPtr in
                body(ablPtr)
            }
        }
    }

    private func withDualBufferABL(
        left: inout [Float],
        right: inout [Float],
        _ body: (UnsafeMutablePointer<AudioBufferList>) -> Void
    ) {
        let allocatedABL = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(allocatedABL.unsafeMutablePointer) }

        let buffers = UnsafeMutableAudioBufferListPointer(allocatedABL.unsafeMutablePointer)
        left.withUnsafeMutableBytes { leftRaw in
            right.withUnsafeMutableBytes { rightRaw in
                buffers[0] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(leftRaw.count),
                    mData: leftRaw.baseAddress
                )
                buffers[1] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(rightRaw.count),
                    mData: rightRaw.baseAddress
                )
                body(allocatedABL.unsafeMutablePointer)
            }
        }
    }
}
