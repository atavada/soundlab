import Testing
@testable import SoundLabCore

@Suite struct AudioDeviceTests {
    @Test func testAudioDeviceCreationAndEquality() {
        let dev1 = AudioDevice(id: 42, uid: "uid-1", name: "Speakers", scope: .output, isDefault: true)
        let dev2 = AudioDevice(id: 42, uid: "uid-1", name: "Speakers", scope: .output, isDefault: false)
        let dev3 = AudioDevice(id: 43, uid: "uid-2", name: "Mic", scope: .input, isDefault: false)

        #expect(dev1 == dev2) // Same ID and UID defines equality
        #expect(dev1 != dev3)
        #expect(dev1.id == 42)
        #expect(dev1.isDefault == true)
    }
}
