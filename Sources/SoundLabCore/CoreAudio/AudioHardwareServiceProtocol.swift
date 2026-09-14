import CoreAudio

public typealias AudioListenerBlock = @Sendable () -> Void

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
    func addDeviceListChangeListener(block: @escaping AudioListenerBlock) throws
    func addDefaultDeviceChangeListener(block: @escaping AudioListenerBlock) throws
}
