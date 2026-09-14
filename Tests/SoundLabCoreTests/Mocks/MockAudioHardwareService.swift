import CoreAudio
import Foundation
@testable import SoundLabCore

public final class MockAudioHardwareService: AudioHardwareServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()
    public var devices: [AudioDeviceID: (uid: String, name: String, scopes: [DeviceScope], volume: Float)] = [:]
    public var defaultOutputID: AudioDeviceID = 0
    public var defaultInputID: AudioDeviceID = 0

    private var deviceListListeners: [AudioListenerBlock] = []
    private var defaultDeviceListeners: [AudioListenerBlock] = []

    public init() {}

    public func addMockDevice(id: AudioDeviceID, uid: String, name: String, scopes: [DeviceScope], volume: Float = 0.5) {
        lock.lock()
        defer { lock.unlock() }
        devices[id] = (uid, name, scopes, volume)
    }

    public func getAllDeviceIDs() throws -> [AudioDeviceID] {
        lock.lock()
        defer { lock.unlock() }
        return Array(devices.keys).sorted()
    }

    public func getDeviceUID(for id: AudioDeviceID) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let dev = devices[id] else { throw SoundLabAudioError.deviceNotFound(id: id) }
        return dev.uid
    }

    public func getDeviceName(for id: AudioDeviceID) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let dev = devices[id] else { throw SoundLabAudioError.deviceNotFound(id: id) }
        return dev.name
    }

    public func getDeviceScopes(for id: AudioDeviceID) throws -> [DeviceScope] {
        lock.lock()
        defer { lock.unlock() }
        guard let dev = devices[id] else { throw SoundLabAudioError.deviceNotFound(id: id) }
        return dev.scopes
    }

    public func getDefaultOutputDeviceID() throws -> AudioDeviceID {
        lock.lock()
        defer { lock.unlock() }
        return defaultOutputID
    }

    public func getDefaultInputDeviceID() throws -> AudioDeviceID {
        lock.lock()
        defer { lock.unlock() }
        return defaultInputID
    }

    public func setDefaultOutputDevice(id: AudioDeviceID) throws {
        lock.lock()
        guard devices[id] != nil else {
            lock.unlock()
            throw SoundLabAudioError.deviceNotFound(id: id)
        }
        defaultOutputID = id
        let listeners = defaultDeviceListeners
        lock.unlock()
        for listener in listeners { listener() }
    }

    public func setDefaultInputDevice(id: AudioDeviceID) throws {
        lock.lock()
        guard devices[id] != nil else {
            lock.unlock()
            throw SoundLabAudioError.deviceNotFound(id: id)
        }
        defaultInputID = id
        let listeners = defaultDeviceListeners
        lock.unlock()
        for listener in listeners { listener() }
    }

    public func getVolume(for id: AudioDeviceID, scope: DeviceScope) throws -> Float {
        lock.lock()
        defer { lock.unlock() }
        guard let dev = devices[id] else { throw SoundLabAudioError.deviceNotFound(id: id) }
        return dev.volume
    }

    public func setVolume(_ volume: Float, for id: AudioDeviceID, scope: DeviceScope) throws {
        lock.lock()
        defer { lock.unlock() }
        guard var dev = devices[id] else { throw SoundLabAudioError.deviceNotFound(id: id) }
        dev.volume = min(max(volume, 0.0), 1.0)
        devices[id] = dev
    }

    public func addDeviceListChangeListener(block: @escaping AudioListenerBlock) throws {
        lock.lock()
        defer { lock.unlock() }
        deviceListListeners.append(block)
    }

    public func addDefaultDeviceChangeListener(block: @escaping AudioListenerBlock) throws {
        lock.lock()
        defer { lock.unlock() }
        defaultDeviceListeners.append(block)
    }

    public func triggerDeviceListChange() {
        lock.lock()
        let listeners = deviceListListeners
        lock.unlock()
        for listener in listeners { listener() }
    }
}
