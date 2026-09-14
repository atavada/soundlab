import Testing
@testable import SoundLabCore

@Suite struct SoundLabCoreTests {
    @Test func versionExists() {
        #expect(SoundLabCoreInfo.version == "1.0.0")
    }
}
