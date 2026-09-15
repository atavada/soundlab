import CoreAudio
import Foundation

public final class CoreAudioHardwareService: AudioHardwareServiceProtocol, @unchecked Sendable {
    public init() {}

    public func getAllDeviceIDs() throws -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return deviceIDs
    }

    public func getDeviceUID(for id: AudioDeviceID) throws -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var unmanaged: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = AudioObjectGetPropertyData(
            id,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &unmanaged
        )
        guard status == noErr, let unmanaged = unmanaged else { throw SoundLabAudioError.halError(status) }
        return unmanaged.takeRetainedValue() as String
    }

    public func getDeviceName(for id: AudioDeviceID) throws -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var unmanaged: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)

        let status = AudioObjectGetPropertyData(
            id,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &unmanaged
        )
        guard status == noErr, let unmanaged = unmanaged else { throw SoundLabAudioError.halError(status) }
        return unmanaged.takeRetainedValue() as String
    }

    public func getDeviceScopes(for id: AudioDeviceID) throws -> [DeviceScope] {
        var scopes: [DeviceScope] = []

        // Check output streams
        var outAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var outSize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(id, &outAddress, 0, nil, &outSize) == noErr && outSize > 0 {
            scopes.append(.output)
        }

        // Check input streams
        var inAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        var inSize: UInt32 = 0
        if AudioObjectGetPropertyDataSize(id, &inAddress, 0, nil, &inSize) == noErr && inSize > 0 {
            scopes.append(.input)
        }

        return scopes
    }

    public func getDefaultOutputDeviceID() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return deviceID
    }

    public func getDefaultInputDeviceID() throws -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return deviceID
    }

    public func setDefaultOutputDevice(id: AudioDeviceID) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = id
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &deviceID
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func setDefaultInputDevice(id: AudioDeviceID) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceID = id
        let dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            dataSize,
            &deviceID
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func getVolume(for id: AudioDeviceID, scope: DeviceScope) throws -> Float {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope.audioObjectPropertyScope,
            mElement: kAudioObjectPropertyElementMain
        )

        var volume: Float32 = 0.0
        var dataSize = UInt32(MemoryLayout<Float32>.size)

        var status = AudioObjectGetPropertyData(id, &propertyAddress, 0, nil, &dataSize, &volume)
        if status != noErr {
            // Fallback to channel 1
            propertyAddress.mElement = 1
            status = AudioObjectGetPropertyData(id, &propertyAddress, 0, nil, &dataSize, &volume)
        }
        guard status == noErr else { throw SoundLabAudioError.volumeNotSupported(id: id) }
        return volume
    }

    public func setVolume(_ volume: Float, for id: AudioDeviceID, scope: DeviceScope) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: scope.audioObjectPropertyScope,
            mElement: kAudioObjectPropertyElementMain
        )

        var vol = min(max(volume, 0.0), 1.0)
        let dataSize = UInt32(MemoryLayout<Float32>.size)

        var status = AudioObjectSetPropertyData(id, &propertyAddress, 0, nil, dataSize, &vol)
        if status != noErr {
            // Fallback to channel 1
            propertyAddress.mElement = 1
            status = AudioObjectSetPropertyData(id, &propertyAddress, 0, nil, dataSize, &vol)
        }
        guard status == noErr else { throw SoundLabAudioError.volumeNotSupported(id: id) }
    }

    private struct VolumeListenerRecord {
        let deviceID: AudioDeviceID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock
    }

    private let listenerLock = NSLock()
    private var deviceListListeners: [AudioListenerToken: AudioObjectPropertyListenerBlock] = [:]
    private var defaultDeviceListeners: [AudioListenerToken: AudioObjectPropertyListenerBlock] = [:]
    private var volumeListeners: [AudioHardwareListenerToken: VolumeListenerRecord] = [:]

    @discardableResult
    public func addDeviceListChangeListener(block: @escaping AudioListenerBlock) throws -> AudioListenerToken {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let listenerBlock: AudioObjectPropertyListenerBlock = { _, _ in
            block()
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }

        let token = UUID()
        listenerLock.lock()
        deviceListListeners[token] = listenerBlock
        listenerLock.unlock()
        return token
    }

    public func removeDeviceListChangeListener(token: AudioListenerToken) throws {
        listenerLock.lock()
        guard let listenerBlock = deviceListListeners.removeValue(forKey: token) else {
            listenerLock.unlock()
            return
        }
        listenerLock.unlock()

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func removeDeviceListChangeListener() throws {
        listenerLock.lock()
        let tokens = Array(deviceListListeners.keys)
        listenerLock.unlock()
        for token in tokens {
            try removeDeviceListChangeListener(token: token)
        }
    }

    @discardableResult
    public func addDefaultDeviceChangeListener(block: @escaping AudioListenerBlock) throws -> AudioListenerToken {
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let listenerBlock: AudioObjectPropertyListenerBlock = { _, _ in
            block()
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            DispatchQueue.main,
            listenerBlock
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }

        let token = UUID()
        listenerLock.lock()
        defaultDeviceListeners[token] = listenerBlock
        listenerLock.unlock()
        return token
    }

    public func removeDefaultDeviceChangeListener(token: AudioListenerToken) throws {
        listenerLock.lock()
        guard let listenerBlock = defaultDeviceListeners.removeValue(forKey: token) else {
            listenerLock.unlock()
            return
        }
        listenerLock.unlock()

        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            DispatchQueue.main,
            listenerBlock
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func removeDefaultDeviceChangeListener() throws {
        listenerLock.lock()
        let tokens = Array(defaultDeviceListeners.keys)
        listenerLock.unlock()
        for token in tokens {
            try removeDefaultDeviceChangeListener(token: token)
        }
    }

    @discardableResult
    public func addVolumeChangeListener(deviceID: AudioDeviceID, block: @escaping AudioListenerBlock) throws -> AudioHardwareListenerToken {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        let listenerBlock: AudioObjectPropertyListenerBlock = { _, _ in
            block()
        }

        var status = AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            listenerBlock
        )
        if status != noErr {
            // Fallback to channel 1
            propertyAddress.mElement = 1
            status = AudioObjectAddPropertyListenerBlock(
                deviceID,
                &propertyAddress,
                DispatchQueue.main,
                listenerBlock
            )
        }
        guard status == noErr else { throw SoundLabAudioError.halError(status) }

        let token = UUID()
        listenerLock.lock()
        volumeListeners[token] = VolumeListenerRecord(deviceID: deviceID, address: propertyAddress, block: listenerBlock)
        listenerLock.unlock()
        return token
    }

    public func removeVolumeChangeListener(token: AudioHardwareListenerToken) {
        listenerLock.lock()
        guard let record = volumeListeners.removeValue(forKey: token) else {
            listenerLock.unlock()
            return
        }
        listenerLock.unlock()

        var address = record.address
        _ = AudioObjectRemovePropertyListenerBlock(
            record.deviceID,
            &address,
            DispatchQueue.main,
            record.block
        )
    }

    public func removeVolumeChangeListener() {
        listenerLock.lock()
        let tokens = Array(volumeListeners.keys)
        listenerLock.unlock()
        for token in tokens {
            removeVolumeChangeListener(token: token)
        }
    }
}
