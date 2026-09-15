import CoreAudio
import Foundation

public typealias AudioListenerBlock = @Sendable () -> Void
public typealias AudioHardwareListenerToken = UUID
public typealias AudioListenerToken = AudioHardwareListenerToken

public protocol AudioHardwareServiceProtocol: Sendable {
    func getAllDeviceIDs() throws -> [AudioDeviceID]
    func getDeviceUID(for id: AudioDeviceID) throws -> String
    func getDeviceName(for id: AudioDeviceID) throws -> String
    func getDeviceScopes(for id: AudioDeviceID) throws -> [DeviceScope]
    func getDefaultOutputDeviceID() throws -> AudioDeviceID
    func getDefaultInputDeviceID() throws -> AudioDeviceID
    func setDefaultOutputDevice(id: AudioDeviceID) throws
    func setDefaultInputDevice(id: AudioDeviceID) throws
    func getVolume(for id: AudioDeviceID, scope: DeviceScope) throws -> Float
    func setVolume(_ volume: Float, for id: AudioDeviceID, scope: DeviceScope) throws
    @discardableResult
    func addDeviceListChangeListener(block: @escaping AudioListenerBlock) throws -> AudioListenerToken
    @discardableResult
    func addDefaultDeviceChangeListener(block: @escaping AudioListenerBlock) throws -> AudioListenerToken
    func removeDeviceListChangeListener(token: AudioListenerToken) throws
    func removeDefaultDeviceChangeListener(token: AudioListenerToken) throws
    @discardableResult
    func addVolumeChangeListener(deviceID: AudioDeviceID, block: @escaping AudioListenerBlock) throws -> AudioHardwareListenerToken
    func removeVolumeChangeListener(token: AudioHardwareListenerToken)
}

public extension AudioHardwareServiceProtocol {
    func removeDeviceListChangeListener() throws {}
    func removeDefaultDeviceChangeListener() throws {}
    func removeVolumeChangeListener(token: AudioHardwareListenerToken) {}
}
