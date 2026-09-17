import CoreAudio
import Foundation

@available(macOS 14.2, *)
public final class ProcessTapController: @unchecked Sendable {
    private let lock = NSLock()

    public let pid: pid_t
    public private(set) var processObjectIDs: [AudioObjectID]
    public var processObjectID: AudioObjectID {
        processObjectIDs.first ?? 0
    }
    public private(set) var outputUID: String
    private let service: ProcessTapServiceProtocol

    public private(set) var tapID: AudioObjectID?
    public private(set) var aggregateID: AudioObjectID?
    public private(set) var procID: AudioDeviceIOProcID?
    public private(set) var tapUUID: UUID?

    public private(set) var volume: Float
    public private(set) var isMuted: Bool
    public private(set) var isActive: Bool = false

    private let volumePointer: UnsafeMutablePointer<Float>

    public var currentGain: Float {
        volumePointer.pointee
    }

    public init(
        pid: pid_t,
        processObjectIDs: [AudioObjectID],
        outputUID: String,
        service: ProcessTapServiceProtocol,
        initialVolume: Float = 1.0
    ) {
        self.pid = pid
        self.processObjectIDs = processObjectIDs
        self.outputUID = outputUID
        self.service = service

        let clamped = min(max(initialVolume, 0.0), 1.0)
        self.volume = clamped
        self.isMuted = false

        self.volumePointer = UnsafeMutablePointer<Float>.allocate(capacity: 1)
        self.volumePointer.initialize(to: clamped)
    }

    public convenience init(
        pid: pid_t,
        processObjectID: AudioObjectID,
        outputUID: String,
        service: ProcessTapServiceProtocol,
        initialVolume: Float = 1.0
    ) {
        self.init(
            pid: pid,
            processObjectIDs: [processObjectID],
            outputUID: outputUID,
            service: service,
            initialVolume: initialVolume
        )
    }

    deinit {
        invalidate()
        volumePointer.deinitialize(count: 1)
        volumePointer.deallocate()
    }

    // MARK: - Volume & Mute Control

    public func setVolume(_ volume: Float) {
        lock.lock()
        defer { lock.unlock() }

        let clamped = min(max(volume, 0.0), 1.0)
        self.volume = clamped

        if !isMuted {
            volumePointer.pointee = clamped
        }
    }

    public func setMuted(_ isMuted: Bool) {
        lock.lock()
        defer { lock.unlock() }

        self.isMuted = isMuted

        if isMuted {
            volumePointer.pointee = 0.0
        } else {
            volumePointer.pointee = self.volume
        }
    }

    // MARK: - Real-Time Audio DSP

    public static func processAudioBufferList(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>,
        volume: Float
    ) {
        let clampedVolume = min(max(volume, 0.0), 1.0)
        let inBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outBuffers = UnsafeMutableAudioBufferListPointer(output)

        guard inBuffers.count > 0 else {
            for b in 0..<outBuffers.count {
                let outBuffer = outBuffers[b]
                if let outData = outBuffer.mData, outBuffer.mDataByteSize > 0 {
                    memset(outData, 0, Int(outBuffer.mDataByteSize))
                }
            }
            return
        }

        let count = min(inBuffers.count, outBuffers.count)

        for b in 0..<count {
            let inBuffer = inBuffers[b]
            let outBuffer = outBuffers[b]
            guard let outData = outBuffer.mData else { continue }
            let outByteSize = outBuffer.mDataByteSize

            guard let inData = inBuffer.mData else {
                if outByteSize > 0 {
                    memset(outData, 0, Int(outByteSize))
                }
                continue
            }

            let byteCount = min(inBuffer.mDataByteSize, outByteSize)

            if byteCount < outByteSize {
                memset(outData.advanced(by: Int(byteCount)), 0, Int(outByteSize - byteCount))
            }

            guard byteCount > 0 else { continue }

            if clampedVolume == 0.0 {
                memset(outData, 0, Int(byteCount))
                continue
            }

            if clampedVolume == 1.0 {
                if inData != outData {
                    memcpy(outData, inData, Int(byteCount))
                }
                continue
            }

            let sampleCount = Int(byteCount) / MemoryLayout<Float>.size
            let inSamples = inData.assumingMemoryBound(to: Float.self)
            let outSamples = outData.assumingMemoryBound(to: Float.self)

            var i = 0
            while i < sampleCount {
                outSamples[i] = inSamples[i] * clampedVolume
                i &+= 1
            }
        }

        if outBuffers.count > count {
            for b in count..<outBuffers.count {
                let outBuffer = outBuffers[b]
                if let outData = outBuffer.mData, outBuffer.mDataByteSize > 0 {
                    memset(outData, 0, Int(outBuffer.mDataByteSize))
                }
            }
        }
    }

    // MARK: - Lifecycle

    public func activate() throws {
        lock.lock()
        defer { lock.unlock() }

        guard !isActive else { return }

        let uuid = UUID()
        self.tapUUID = uuid

        let newTapID = try service.createProcessTap(for: processObjectIDs, tapUUID: uuid)
        self.tapID = newTapID

        do {
            let aggID = try createAggregateAndStartIO(tapUUID: uuid, outputUID: self.outputUID)
            self.aggregateID = aggID
            self.isActive = true
        } catch {
            try? service.destroyProcessTap(newTapID)
            self.tapID = nil
            self.tapUUID = nil
            throw error
        }
    }

    public func updateProcessObjectIDs(_ newObjectIDs: [AudioObjectID]) throws {
        lock.lock()
        let currentSet = Set(self.processObjectIDs)
        let newSet = Set(newObjectIDs)
        if currentSet == newSet {
            lock.unlock()
            return
        }
        self.processObjectIDs = newObjectIDs
        let wasActive = self.isActive
        let outUID = self.outputUID
        lock.unlock()

        if wasActive {
            lock.lock()
            defer { lock.unlock() }

            if let aggID = self.aggregateID, let pID = self.procID {
                try? service.stopIO(aggregateID: aggID, procID: pID)
                try? service.destroyIOProc(aggregateID: aggID, procID: pID)
                self.procID = nil
            }
            if let aggID = self.aggregateID {
                try? service.destroyAggregateDevice(aggID)
                self.aggregateID = nil
            }
            if let tID = self.tapID {
                try? service.destroyProcessTap(tID)
                self.tapID = nil
            }

            let uuid = UUID()
            self.tapUUID = uuid
            let newTapID = try service.createProcessTap(for: self.processObjectIDs, tapUUID: uuid)
            self.tapID = newTapID

            do {
                let newAggID = try createAggregateAndStartIO(tapUUID: uuid, outputUID: outUID)
                self.aggregateID = newAggID
                self.isActive = true
            } catch {
                try? service.destroyProcessTap(newTapID)
                self.tapID = nil
                self.tapUUID = nil
                self.isActive = false
                throw error
            }
        }
    }

    public func recreate(newOutputUID: String) throws {
        lock.lock()
        defer { lock.unlock() }

        self.outputUID = newOutputUID

        guard isActive, let tapUUID = self.tapUUID else { return }

        // Teardown existing aggregate device and IOProc
        if let aggID = self.aggregateID, let pID = self.procID {
            try? service.stopIO(aggregateID: aggID, procID: pID)
            try? service.destroyIOProc(aggregateID: aggID, procID: pID)
            self.procID = nil
        }
        if let aggID = self.aggregateID {
            try? service.destroyAggregateDevice(aggID)
            self.aggregateID = nil
        }

        // Rebuild aggregate and start IO with existing tapUUID and new outputUID
        do {
            let newAggID = try createAggregateAndStartIO(tapUUID: tapUUID, outputUID: newOutputUID)
            self.aggregateID = newAggID
        } catch {
            self.isActive = false
            throw error
        }
    }

    public func invalidate() {
        lock.lock()
        defer { lock.unlock() }

        if let aggID = self.aggregateID, let pID = self.procID {
            try? service.stopIO(aggregateID: aggID, procID: pID)
            try? service.destroyIOProc(aggregateID: aggID, procID: pID)
            self.procID = nil
        }
        if let aggID = self.aggregateID {
            try? service.destroyAggregateDevice(aggID)
            self.aggregateID = nil
        }
        if let tID = self.tapID {
            try? service.destroyProcessTap(tID)
            self.tapID = nil
        }

        self.tapUUID = nil
        self.isActive = false
    }

    // MARK: - Private Helpers

    private func createAggregateAndStartIO(tapUUID: UUID, outputUID: String) throws -> AudioObjectID {
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SoundLab-\(tapUUID.uuidString)",
            kAudioAggregateDeviceUIDKey: "SoundLab.Aggregate.\(tapUUID.uuidString)",
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapUIDKey: tapUUID.uuidString,
                kAudioSubTapDriftCompensationKey: true
            ]],
            kAudioAggregateDeviceSubDeviceListKey: [[
                kAudioSubDeviceUIDKey: outputUID
            ]],
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true
        ]

        let aggID = try service.createAggregateDevice(description: description as CFDictionary)

        nonisolated(unsafe) let volPtr = self.volumePointer
        let block: ProcessTapIOBlock = { _, inInputData, _, outOutputData, _ in
            let currentVol = volPtr.pointee
            Self.processAudioBufferList(input: inInputData, output: outOutputData, volume: currentVol)
        }

        let pID: AudioDeviceIOProcID
        do {
            pID = try service.createIOProc(aggregateID: aggID, block: block)
            self.procID = pID
        } catch {
            try? service.destroyAggregateDevice(aggID)
            throw error
        }

        do {
            try service.startIO(aggregateID: aggID, procID: pID)
        } catch {
            try? service.destroyIOProc(aggregateID: aggID, procID: pID)
            self.procID = nil
            try? service.destroyAggregateDevice(aggID)
            throw error
        }

        return aggID
    }
}
