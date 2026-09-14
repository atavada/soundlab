import Testing
@testable import SoundLabCore

@Suite struct DeviceScopeTests {
    @Test func testScopeDisplayNames() {
        #expect(DeviceScope.output.displayName == "Output")
        #expect(DeviceScope.input.displayName == "Input")
        #expect(DeviceScope.systemOutput.displayName == "System Output")
    }
}
