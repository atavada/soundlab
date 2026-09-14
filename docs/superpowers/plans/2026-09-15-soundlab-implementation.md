# SoundLab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and package SoundLab, a native macOS menu bar audio device switching and volume persistence utility.

**Architecture:** Modular SPM multi-target package: `SoundLabCore` (CoreAudio HAL C-API wrapper, managers, and persistence, AppKit-free), `SoundLabUI` (AppKit `NSStatusItem`, custom `NSMenu` slider, preferences window, Carbon hotkeys), and `SoundLabApp` (executable entry point and bundle packaging).

**Tech Stack:** Swift 6.0+, macOS CoreAudio HAL, AppKit, Carbon HIToolbox, UserNotifications, ServiceManagement, Swift Package Manager.

**Spec:** [docs/superpowers/specs/2026-09-15-soundlab-design.md](docs/superpowers/specs/2026-09-15-soundlab-design.md)

## Global Constraints
- Target platform: macOS 11.0+ (`arm64` and `x86_64`)
- Swift language mode: Swift 6 with strict concurrency checking
- Background agent: `LSUIElement = true` (zero dock presence)
- Global hotkeys: Carbon HIToolbox (`RegisterEventHotKey`), no Accessibility permissions required
- No `Co-Authored-By` trailer in git commit messages

---

## File Structure Map

```
SoundLab/
├── Package.swift
├── Makefile
├── scripts/
│   └── bundle.sh
├── Sources/
│   ├── SoundLabCore/
│   │   ├── Models/
│   │   │   ├── DeviceScope.swift
│   │   │   ├── AudioDevice.swift
│   │   │   └── SoundLabAudioError.swift
│   │   ├── CoreAudio/
│   │   │   ├── AudioHardwareServiceProtocol.swift
│   │   │   └── CoreAudioHardwareService.swift
│   │   └── Managers/
│   │       ├── SettingsManager.swift
│   │       ├── VolumeManager.swift
│   │       ├── DeviceManager.swift
│   │       └── DeviceObserver.swift
│   ├── SoundLabUI/
│   │   ├── Menu/
│   │   │   ├── VolumeSliderMenuItem.swift
│   │   │   ├── MenuBuilder.swift
│   │   │   └── StatusBarController.swift
│   │   ├── Preferences/
│   │   │   ├── GeneralPreferencesViewController.swift
│   │   │   └── PreferencesWindowController.swift
│   │   ├── Hotkeys/
│   │   │   └── CarbonHotkeyManager.swift
│   │   └── Feedback/
│   │       └── NotificationDispatcher.swift
│   └── SoundLabApp/
│       ├── Info.plist
│       ├── AppDelegate.swift
│       └── main.swift
└── Tests/
    └── SoundLabCoreTests/
        ├── Mocks/
        │   └── MockAudioHardwareService.swift
        ├── DeviceScopeTests.swift
        ├── AudioDeviceTests.swift
        ├── SettingsManagerTests.swift
        ├── VolumeManagerTests.swift
        └── DeviceManagerTests.swift
```

---

### Task 1: SPM Package & Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Sources/SoundLabCore/SoundLabCore.swift`
- Create: `Sources/SoundLabUI/SoundLabUI.swift`
- Create: `Sources/SoundLabApp/main.swift`
- Create: `Tests/SoundLabCoreTests/SoundLabCoreTests.swift`

**Interfaces:**
- Produces: Valid SPM multi-target build structure with targets `SoundLabCore`, `SoundLabUI`, `SoundLabApp`, and test target `SoundLabCoreTests`.

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SoundLab",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(name: "SoundLabCore", targets: ["SoundLabCore"]),
        .library(name: "SoundLabUI", targets: ["SoundLabUI"]),
        .executable(name: "SoundLabApp", targets: ["SoundLabApp"])
    ],
    targets: [
        .target(
            name: "SoundLabCore",
            dependencies: [],
            path: "Sources/SoundLabCore"
        ),
        .target(
            name: "SoundLabUI",
            dependencies: ["SoundLabCore"],
            path: "Sources/SoundLabUI"
        ),
        .executableTarget(
            name: "SoundLabApp",
            dependencies: ["SoundLabCore", "SoundLabUI"],
            path: "Sources/SoundLabApp"
        ),
        .testTarget(
            name: "SoundLabCoreTests",
            dependencies: ["SoundLabCore"],
            path: "Tests/SoundLabCoreTests"
        )
    ]
)
```

- [ ] **Step 2: Create placeholder files**

```swift
// Sources/SoundLabCore/SoundLabCore.swift
public struct SoundLabCoreInfo {
    public static let version = "1.0.0"
}
```

```swift
// Sources/SoundLabUI/SoundLabUI.swift
import SoundLabCore

public struct SoundLabUIInfo {
    public static let version = "1.0.0"
}
```

```swift
// Sources/SoundLabApp/main.swift
import SoundLabCore
import SoundLabUI

print("SoundLab initialized")
```

```swift
// Tests/SoundLabCoreTests/SoundLabCoreTests.swift
import Testing
@testable import SoundLabCore

@Suite struct SoundLabCoreTests {
    @Test func versionExists() {
        #expect(SoundLabCoreInfo.version == "1.0.0")
    }
}
```

- [ ] **Step 3: Run swift build and swift test**

Run: `swift build && swift test`
Expected: PASS (build complete, test passed)

- [ ] **Step 4: Commit**

```bash
git add Package.swift Sources/ Tests/
git commit -m "chore: scaffold modular SPM package with SoundLabCore, SoundLabUI, and SoundLabApp"
```

---

### Task 2: Core Models & Error Types

**Files:**
- Create: `Sources/SoundLabCore/Models/DeviceScope.swift`
- Create: `Sources/SoundLabCore/Models/AudioDevice.swift`
- Create: `Sources/SoundLabCore/Models/SoundLabAudioError.swift`
- Create: `Tests/SoundLabCoreTests/DeviceScopeTests.swift`
- Create: `Tests/SoundLabCoreTests/AudioDeviceTests.swift`

**Interfaces:**
- Produces:
  - `DeviceScope`: `case input`, `case output`, `case systemOutput`
  - `AudioDevice`: `struct AudioDevice: Identifiable, Hashable, Sendable` with `id: UInt32`, `uid: String`, `name: String`, `scope: DeviceScope`, `isDefault: Bool`
  - `SoundLabAudioError`: `enum SoundLabAudioError: Error, Equatable, Sendable`

- [ ] **Step 1: Write failing tests for models**

```swift
// Tests/SoundLabCoreTests/DeviceScopeTests.swift
import Testing
@testable import SoundLabCore

@Suite struct DeviceScopeTests {
    @Test func testScopeDisplayNames() {
        #expect(DeviceScope.output.displayName == "Output")
        #expect(DeviceScope.input.displayName == "Input")
        #expect(DeviceScope.systemOutput.displayName == "System Output")
    }
}
```

```swift
// Tests/SoundLabCoreTests/AudioDeviceTests.swift
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
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL (Cannot find `DeviceScope`, `AudioDevice`)

- [ ] **Step 3: Implement DeviceScope, AudioDevice, and SoundLabAudioError**

```swift
// Sources/SoundLabCore/Models/DeviceScope.swift
import CoreAudio

public enum DeviceScope: Sendable, Hashable, CaseIterable {
    case output
    case input
    case systemOutput

    public var displayName: String {
        switch self {
        case .output: return "Output"
        case .input: return "Input"
        case .systemOutput: return "System Output"
        }
    }

    public var audioObjectPropertyScope: AudioObjectPropertyScope {
        switch self {
        case .output, .systemOutput:
            return kAudioObjectPropertyScopeOutput
        case .input:
            return kAudioObjectPropertyScopeInput
        }
    }
}
```

```swift
// Sources/SoundLabCore/Models/AudioDevice.swift
import CoreAudio

public struct AudioDevice: Identifiable, Hashable, Sendable {
    public let id: AudioDeviceID
    public let uid: String
    public let name: String
    public let scope: DeviceScope
    public let isDefault: Bool

    public init(id: AudioDeviceID, uid: String, name: String, scope: DeviceScope, isDefault: Bool = false) {
        self.id = id
        self.uid = uid
        self.name = name
        self.scope = scope
        self.isDefault = isDefault
    }

    public static func == (lhs: AudioDevice, rhs: AudioDevice) -> Bool {
        lhs.id == rhs.id && lhs.uid == rhs.uid
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(uid)
    }
}
```

```swift
// Sources/SoundLabCore/Models/SoundLabAudioError.swift
import CoreAudio

public enum SoundLabAudioError: Error, Equatable, Sendable {
    case deviceNotFound(id: AudioDeviceID)
    case deviceUIDNotFound(uid: String)
    case volumeNotSupported(id: AudioDeviceID)
    case halError(OSStatus)
    case propertyFetchFailed(String)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabCore/Models/ Tests/SoundLabCoreTests/
git commit -m "feat(core): add DeviceScope, AudioDevice, and SoundLabAudioError models"
```

---

### Task 3: Audio Hardware Protocol & Mock Service

**Files:**
- Create: `Sources/SoundLabCore/CoreAudio/AudioHardwareServiceProtocol.swift`
- Create: `Sources/SoundLabCore/CoreAudio/CoreAudioHardwareService.swift`
- Create: `Tests/SoundLabCoreTests/Mocks/MockAudioHardwareService.swift`

**Interfaces:**
- Produces:
  - `AudioHardwareServiceProtocol`: Sendable interface defining all CoreAudio HAL queries, default routing, and volume mutations.
  - `MockAudioHardwareService`: In-memory thread-safe mock for tests.
  - `CoreAudioHardwareService`: Production CoreAudio C API wrapper.

- [ ] **Step 1: Define AudioHardwareServiceProtocol**

```swift
// Sources/SoundLabCore/CoreAudio/AudioHardwareServiceProtocol.swift
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
```

- [ ] **Step 2: Implement MockAudioHardwareService**

```swift
// Tests/SoundLabCoreTests/Mocks/MockAudioHardwareService.swift
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
```

- [ ] **Step 3: Implement CoreAudioHardwareService**

```swift
// Sources/SoundLabCore/CoreAudio/CoreAudioHardwareService.swift
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

        var deviceUID: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(
            id,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceUID
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return deviceUID as String
    }

    public func getDeviceName(for id: AudioDeviceID) throws -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var deviceName: CFString = "" as CFString
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(
            id,
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceName
        )
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
        return deviceName as String
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

    public func addDeviceListChangeListener(block: @escaping AudioListenerBlock) throws {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main
        ) { _, _ in
            block()
        }
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }

    public func addDefaultDeviceChangeListener(block: @escaping AudioListenerBlock) throws {
        var outputAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputAddress,
            DispatchQueue.main
        ) { _, _ in
            block()
        }
        guard status == noErr else { throw SoundLabAudioError.halError(status) }
    }
}
```

- [ ] **Step 4: Run swift build & test**

Run: `swift build && swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabCore/CoreAudio/ Tests/SoundLabCoreTests/Mocks/
git commit -m "feat(core): implement AudioHardwareServiceProtocol and CoreAudioHardwareService"
```

---

### Task 4: Settings Manager (UserDefaults Persistence)

**Files:**
- Create: `Sources/SoundLabCore/Managers/SettingsManager.swift`
- Create: `Tests/SoundLabCoreTests/SettingsManagerTests.swift`

**Interfaces:**
- Produces:
  - `SettingsManager`: Thread-safe persistence manager for per-device volume memory and app preferences.

- [ ] **Step 1: Write failing tests for SettingsManager**

```swift
// Tests/SoundLabCoreTests/SettingsManagerTests.swift
import Testing
import Foundation
@testable import SoundLabCore

@Suite struct SettingsManagerTests {
    @Test func testVolumePersistence() {
        let suiteName = "com.soundlab.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.getSavedVolume(for: "test-uid-1") == nil)

        settings.saveVolume(0.75, for: "test-uid-1")
        #expect(settings.getSavedVolume(for: "test-uid-1") == 0.75)

        settings.saveVolume(0.20, for: "test-uid-1")
        #expect(settings.getSavedVolume(for: "test-uid-1") == 0.20)
    }

    @Test func testPreferencesDefaults() {
        let suiteName = "com.soundlab.test.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let settings = SettingsManager(userDefaults: userDefaults)
        #expect(settings.showDeviceNameInMenuBar == false)
        #expect(settings.showNotificationBanner == true)

        settings.showDeviceNameInMenuBar = true
        #expect(settings.showDeviceNameInMenuBar == true)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL (Cannot find `SettingsManager`)

- [ ] **Step 3: Implement SettingsManager**

```swift
// Sources/SoundLabCore/Managers/SettingsManager.swift
import Foundation

public final class SettingsManager: @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let lock = NSLock()

    private enum Keys {
        static let volumePrefix = "soundlab.vol."
        static let launchAtLogin = "soundlab.launchAtLogin"
        static let showDeviceNameInMenuBar = "soundlab.showDeviceNameInMenuBar"
        static let showNotificationBanner = "soundlab.showNotificationBanner"
        static let hotkeysEnabled = "soundlab.hotkeysEnabled"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func getSavedVolume(for deviceUID: String) -> Float? {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        guard userDefaults.object(forKey: key) != nil else { return nil }
        return userDefaults.float(forKey: key)
    }

    public func saveVolume(_ volume: Float, for deviceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        userDefaults.set(min(max(volume, 0.0), 1.0), forKey: key)
    }

    public func removeSavedVolume(for deviceUID: String) {
        lock.lock()
        defer { lock.unlock() }
        let key = Keys.volumePrefix + deviceUID
        userDefaults.removeObject(forKey: key)
    }

    public var showDeviceNameInMenuBar: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: Keys.showDeviceNameInMenuBar)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.showDeviceNameInMenuBar)
        }
    }

    public var showNotificationBanner: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if userDefaults.object(forKey: Keys.showNotificationBanner) == nil {
                return true // default true
            }
            return userDefaults.bool(forKey: Keys.showNotificationBanner)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.showNotificationBanner)
        }
    }

    public var hotkeysEnabled: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            if userDefaults.object(forKey: Keys.hotkeysEnabled) == nil {
                return true // default true
            }
            return userDefaults.bool(forKey: Keys.hotkeysEnabled)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.hotkeysEnabled)
        }
    }

    public var launchAtLogin: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return userDefaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            userDefaults.set(newValue, forKey: Keys.launchAtLogin)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabCore/Managers/SettingsManager.swift Tests/SoundLabCoreTests/SettingsManagerTests.swift
git commit -m "feat(core): implement SettingsManager for UserDefaults volume and preferences persistence"
```

---

### Task 5: Volume Manager

**Files:**
- Create: `Sources/SoundLabCore/Managers/VolumeManager.swift`
- Create: `Tests/SoundLabCoreTests/VolumeManagerTests.swift`

**Interfaces:**
- Consumes: `AudioHardwareServiceProtocol`, `SettingsManager`
- Produces:
  - `VolumeManager`: Coordinates volume reading/writing, per-device volume restoration, and volume change dispatching.

- [ ] **Step 1: Write failing tests for VolumeManager**

```swift
// Tests/SoundLabCoreTests/VolumeManagerTests.swift
import Testing
import Foundation
@testable import SoundLabCore

@Suite struct VolumeManagerTests {
    @Test func testGetAndSetOutputVolumeClamped() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", scopes: [.output], volume: 0.5)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

        let vol = try volumeManager.getOutputVolume()
        #expect(vol == 0.5)

        try volumeManager.setOutputVolume(0.85)
        #expect(try volumeManager.getOutputVolume() == 0.85)
        #expect(settings.getSavedVolume(for: "dev-1") == 0.85)

        // Test upper clamp
        try volumeManager.setOutputVolume(1.5)
        #expect(try volumeManager.getOutputVolume() == 1.0)

        // Test lower clamp
        try volumeManager.setOutputVolume(-0.2)
        #expect(try volumeManager.getOutputVolume() == 0.0)
    }

    @Test func testRestoreSavedVolumeOnDeviceSwitch() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "dev-1", scopes: [.output], volume: 0.3)
        mock.addMockDevice(id: 2, uid: "dev-2", scopes: [.output], volume: 0.9)
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "vol-test-\(UUID().uuidString)")!)
        settings.saveVolume(0.65, for: "dev-2")

        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        try volumeManager.restoreVolume(for: "dev-2", deviceID: 2)

        #expect(try mock.getVolume(for: 2, scope: .output) == 0.65)
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL (Cannot find `VolumeManager`)

- [ ] **Step 3: Implement VolumeManager**

```swift
// Sources/SoundLabCore/Managers/VolumeManager.swift
import CoreAudio
import Foundation

public final class VolumeManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let settingsManager: SettingsManager
    private let lock = NSLock()
    private var volumeChangeCallbacks: [@Sendable (Float) -> Void] = []

    public init(hardwareService: AudioHardwareServiceProtocol, settingsManager: SettingsManager) {
        self.hardwareService = hardwareService
        self.settingsManager = settingsManager
    }

    public func getOutputVolume() throws -> Float {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        return try hardwareService.getVolume(for: defaultID, scope: .output)
    }

    public func setOutputVolume(_ volume: Float) throws {
        let defaultID = try hardwareService.getDefaultOutputDeviceID()
        let clamped = min(max(volume, 0.0), 1.0)
        try hardwareService.setVolume(clamped, for: defaultID, scope: .output)

        if let uid = try? hardwareService.getDeviceUID(for: defaultID) {
            settingsManager.saveVolume(clamped, for: uid)
        }

        notifyVolumeChange(clamped)
    }

    public func restoreVolume(for deviceUID: String, deviceID: AudioDeviceID) throws {
        if let savedVolume = settingsManager.getSavedVolume(for: deviceUID) {
            try hardwareService.setVolume(savedVolume, for: deviceID, scope: .output)
            notifyVolumeChange(savedVolume)
        } else {
            // Save initial volume as baseline
            if let currentVolume = try? hardwareService.getVolume(for: deviceID, scope: .output) {
                settingsManager.saveVolume(currentVolume, for: deviceUID)
            }
        }
    }

    public func addVolumeChangeObserver(callback: @escaping @Sendable (Float) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        volumeChangeCallbacks.append(callback)
    }

    private func notifyVolumeChange(_ volume: Float) {
        lock.lock()
        let callbacks = volumeChangeCallbacks
        lock.unlock()
        for callback in callbacks {
            callback(volume)
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabCore/Managers/VolumeManager.swift Tests/SoundLabCoreTests/VolumeManagerTests.swift
git commit -m "feat(core): implement VolumeManager with per-device persistence and volume clamping"
```

---

### Task 6: Device Manager & Device Observer

**Files:**
- Create: `Sources/SoundLabCore/Managers/DeviceManager.swift`
- Create: `Sources/SoundLabCore/Managers/DeviceObserver.swift`
- Create: `Tests/SoundLabCoreTests/DeviceManagerTests.swift`

**Interfaces:**
- Consumes: `AudioHardwareServiceProtocol`, `VolumeManager`, `SettingsManager`
- Produces:
  - `DeviceManager`: Enumerates devices, handles default device switching, restores device volume, cycles next device.
  - `DeviceObserver`: Watches hardware property listeners and notifies `DeviceManager`.

- [ ] **Step 1: Write failing tests for DeviceManager**

```swift
// Tests/SoundLabCoreTests/DeviceManagerTests.swift
import Testing
import Foundation
@testable import SoundLabCore

@Suite struct DeviceManagerTests {
    @Test func testEnumerateDevices() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.addMockDevice(id: 3, uid: "in-1", name: "Mic", scopes: [.input])
        mock.defaultOutputID = 1
        mock.defaultInputID = 3

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)

        try deviceManager.refreshDevices()

        let outputs = deviceManager.outputDevices
        let inputs = deviceManager.inputDevices

        #expect(outputs.count == 2)
        #expect(inputs.count == 1)
        #expect(outputs.first { $0.isDefault }?.uid == "out-1")
        #expect(inputs.first { $0.isDefault }?.uid == "in-1")
    }

    @Test func testSwitchDefaultOutputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        settings.saveVolume(0.8, for: "out-2")

        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.setDefaultOutput(deviceUID: "out-2")

        #expect(mock.defaultOutputID == 2)
        #expect(deviceManager.defaultOutputDevice?.uid == "out-2")
        #expect(try mock.getVolume(for: 2, scope: .output) == 0.8)
    }

    @Test func testCycleNextOutputDevice() throws {
        let mock = MockAudioHardwareService()
        mock.addMockDevice(id: 1, uid: "out-1", name: "Speakers", scopes: [.output])
        mock.addMockDevice(id: 2, uid: "out-2", name: "Headphones", scopes: [.output])
        mock.defaultOutputID = 1

        let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "dev-test-\(UUID().uuidString)")!)
        let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)
        let deviceManager = DeviceManager(hardwareService: mock, volumeManager: volumeManager, settingsManager: settings)
        try deviceManager.refreshDevices()

        try deviceManager.cycleNextOutputDevice()
        #expect(mock.defaultOutputID == 2)

        try deviceManager.cycleNextOutputDevice()
        #expect(mock.defaultOutputID == 1) // Wraps around
    }
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL (Cannot find `DeviceManager`)

- [ ] **Step 3: Implement DeviceManager and DeviceObserver**

```swift
// Sources/SoundLabCore/Managers/DeviceManager.swift
import CoreAudio
import Foundation

public final class DeviceManager: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    private let lock = NSLock()

    public private(set) var outputDevices: [AudioDevice] = []
    public private(set) var inputDevices: [AudioDevice] = []

    public var defaultOutputDevice: AudioDevice? {
        outputDevices.first { $0.isDefault }
    }

    public var defaultInputDevice: AudioDevice? {
        inputDevices.first { $0.isDefault }
    }

    private var changeListeners: [@Sendable () -> Void] = []

    public init(hardwareService: AudioHardwareServiceProtocol, volumeManager: VolumeManager, settingsManager: SettingsManager) {
        self.hardwareService = hardwareService
        self.volumeManager = volumeManager
        self.settingsManager = settingsManager
    }

    public func refreshDevices() throws {
        lock.lock()
        defer { lock.unlock() }

        let allIDs = try hardwareService.getAllDeviceIDs()
        let defOutID = (try? hardwareService.getDefaultOutputDeviceID()) ?? 0
        let defInID = (try? hardwareService.getDefaultInputDeviceID()) ?? 0

        var newOutputs: [AudioDevice] = []
        var newInputs: [AudioDevice] = []

        for id in allIDs {
            guard let uid = try? hardwareService.getDeviceUID(for: id),
                  let name = try? hardwareService.getDeviceName(for: id),
                  let scopes = try? hardwareService.getDeviceScopes(for: id) else {
                continue
            }

            if scopes.contains(.output) {
                let isDef = (id == defOutID)
                newOutputs.append(AudioDevice(id: id, uid: uid, name: name, scope: .output, isDefault: isDef))
            }

            if scopes.contains(.input) {
                let isDef = (id == defInID)
                newInputs.append(AudioDevice(id: id, uid: uid, name: name, scope: .input, isDefault: isDef))
            }
        }

        self.outputDevices = newOutputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        self.inputDevices = newInputs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        notifyListeners()
    }

    public func setDefaultOutput(deviceUID: String) throws {
        lock.lock()
        guard let device = outputDevices.first(where: { $0.uid == deviceUID }) else {
            lock.unlock()
            throw SoundLabAudioError.deviceUIDNotFound(uid: deviceUID)
        }
        lock.unlock()

        try hardwareService.setDefaultOutputDevice(id: device.id)
        try volumeManager.restoreVolume(for: deviceUID, deviceID: device.id)
        try refreshDevices()
    }

    public func setDefaultInput(deviceUID: String) throws {
        lock.lock()
        guard let device = inputDevices.first(where: { $0.uid == deviceUID }) else {
            lock.unlock()
            throw SoundLabAudioError.deviceUIDNotFound(uid: deviceUID)
        }
        lock.unlock()

        try hardwareService.setDefaultInputDevice(id: device.id)
        try refreshDevices()
    }

    public func cycleNextOutputDevice() throws {
        lock.lock()
        guard !outputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = outputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % outputDevices.count
        let nextDevice = outputDevices[nextIndex]
        lock.unlock()

        try setDefaultOutput(deviceUID: nextDevice.uid)
    }

    public func cycleNextInputDevice() throws {
        lock.lock()
        guard !inputDevices.isEmpty else {
            lock.unlock()
            return
        }
        let currentIndex = inputDevices.firstIndex { $0.isDefault } ?? -1
        let nextIndex = (currentIndex + 1) % inputDevices.count
        let nextDevice = inputDevices[nextIndex]
        lock.unlock()

        try setDefaultInput(deviceUID: nextDevice.uid)
    }

    public func addChangeListener(listener: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        changeListeners.append(listener)
    }

    private func notifyListeners() {
        let listeners = changeListeners
        for listener in listeners {
            listener()
        }
    }
}
```

```swift
// Sources/SoundLabCore/Managers/DeviceObserver.swift
import Foundation

public final class DeviceObserver: @unchecked Sendable {
    private let hardwareService: AudioHardwareServiceProtocol
    private weak var deviceManager: DeviceManager?

    public init(hardwareService: AudioHardwareServiceProtocol, deviceManager: DeviceManager) {
        self.hardwareService = hardwareService
        self.deviceManager = deviceManager
    }

    public func startObserving() {
        try? hardwareService.addDeviceListChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }

        try? hardwareService.addDefaultDeviceChangeListener { [weak self] in
            DispatchQueue.main.async {
                try? self?.deviceManager?.refreshDevices()
            }
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabCore/Managers/ Tests/SoundLabCoreTests/DeviceManagerTests.swift
git commit -m "feat(core): implement DeviceManager and DeviceObserver for device routing and hotplug monitoring"
```

---

### Task 7: SoundLabUI Menu Components & Status Bar

**Files:**
- Create: `Sources/SoundLabUI/Menu/VolumeSliderMenuItem.swift`
- Create: `Sources/SoundLabUI/Menu/MenuBuilder.swift`
- Create: `Sources/SoundLabUI/Menu/StatusBarController.swift`

**Interfaces:**
- Consumes: `SoundLabCore.DeviceManager`, `SoundLabCore.VolumeManager`, `SoundLabCore.SettingsManager`
- Produces:
  - `StatusBarController`: Manages AppKit `NSStatusItem`, icon updates, menu presentation.
  - `VolumeSliderMenuItem`: Custom `NSMenuItem` hosting `NSSlider` with live percentage label.

- [ ] **Step 1: Implement VolumeSliderMenuItem**

```swift
// Sources/SoundLabUI/Menu/VolumeSliderMenuItem.swift
import AppKit
import SoundLabCore

public final class VolumeSliderMenuItem: NSMenuItem {
    private let slider = NSSlider()
    private let percentageLabel = NSTextField(labelWithString: "100%")
    private let iconView = NSImageView()
    private weak var volumeManager: VolumeManager?

    public init(volumeManager: VolumeManager) {
        self.volumeManager = volumeManager
        super.init(title: "", action: nil, keyEquivalent: "")

        setupView()
        updateSliderPosition()

        volumeManager.addVolumeChangeObserver { [weak self] vol in
            DispatchQueue.main.async {
                self?.slider.floatValue = vol
                self?.percentageLabel.stringValue = "\(Int(round(vol * 100)))%"
            }
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 32))

        iconView.frame = NSRect(x: 14, y: 8, width: 16, height: 16)
        if #available(macOS 11.0, *) {
            iconView.image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "Volume")
        }

        slider.frame = NSRect(x: 36, y: 6, width: 125, height: 20)
        slider.minValue = 0.0
        slider.maxValue = 1.0
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderMoved(_:))

        percentageLabel.frame = NSRect(x: 168, y: 6, width: 45, height: 18)
        percentageLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        percentageLabel.textColor = .secondaryLabelColor

        container.addSubview(iconView)
        container.addSubview(slider)
        container.addSubview(percentageLabel)
        self.view = container
    }

    @objc private func sliderMoved(_ sender: NSSlider) {
        let val = sender.floatValue
        percentageLabel.stringValue = "\(Int(round(val * 100)))%"
        try? volumeManager?.setOutputVolume(val)
    }

    private func updateSliderPosition() {
        if let currentVol = try? volumeManager?.getOutputVolume() {
            slider.floatValue = currentVol
            percentageLabel.stringValue = "\(Int(round(currentVol * 100)))%"
        }
    }
}
```

- [ ] **Step 2: Implement MenuBuilder**

```swift
// Sources/SoundLabUI/Menu/MenuBuilder.swift
import AppKit
import SoundLabCore

@MainActor
public final class MenuBuilder {
    public static func buildMenu(
        deviceManager: DeviceManager,
        volumeManager: VolumeManager,
        target: AnyObject,
        selectOutputAction: Selector,
        selectInputAction: Selector,
        openPreferencesAction: Selector,
        quitAction: Selector
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // Section: Output Devices
        let outputHeader = NSMenuItem(title: "OUTPUT DEVICES", action: nil, keyEquivalent: "")
        outputHeader.isEnabled = false
        menu.addItem(outputHeader)

        for device in deviceManager.outputDevices {
            let item = NSMenuItem(title: device.name, action: selectOutputAction, keyEquivalent: "")
            item.target = target
            item.representedObject = device.uid
            item.state = device.isDefault ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Section: Output Volume Slider
        let sliderItem = VolumeSliderMenuItem(volumeManager: volumeManager)
        menu.addItem(sliderItem)

        menu.addItem(NSMenuItem.separator())

        // Section: Input Devices
        let inputHeader = NSMenuItem(title: "INPUT DEVICES", action: nil, keyEquivalent: "")
        inputHeader.isEnabled = false
        menu.addItem(inputHeader)

        for device in deviceManager.inputDevices {
            let item = NSMenuItem(title: device.name, action: selectInputAction, keyEquivalent: "")
            item.target = target
            item.representedObject = device.uid
            item.state = device.isDefault ? .on : .off
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        // Section: Preferences & Quit
        let prefsItem = NSMenuItem(title: "Preferences…", action: openPreferencesAction, keyEquivalent: ",")
        prefsItem.target = target
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(title: "Quit SoundLab", action: quitAction, keyEquivalent: "q")
        quitItem.target = target
        menu.addItem(quitItem)

        return menu
    }
}
```

- [ ] **Step 3: Implement StatusBarController**

```swift
// Sources/SoundLabUI/Menu/StatusBarController.swift
import AppKit
import SoundLabCore

@MainActor
public final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let deviceManager: DeviceManager
    private let volumeManager: VolumeManager
    private let settingsManager: SettingsManager
    public var onOpenPreferences: (() -> Void)?

    public init(deviceManager: DeviceManager, volumeManager: VolumeManager, settingsManager: SettingsManager) {
        self.deviceManager = deviceManager
        self.volumeManager = volumeManager
        self.settingsManager = settingsManager
        super.init()
        setupStatusItem()
        rebuildMenu()

        deviceManager.addChangeListener { [weak self] in
            DispatchQueue.main.async {
                self?.rebuildMenu()
                self?.updateStatusItemTitle()
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if #available(macOS 11.0, *) {
                let image = NSImage(systemSymbolName: "speaker.wave.2.fill", accessibilityDescription: "SoundLab")
                image?.isTemplate = true
                button.image = image
            }
        }
        updateStatusItemTitle()
    }

    public func updateStatusItemTitle() {
        guard let button = statusItem?.button else { return }
        if settingsManager.showDeviceNameInMenuBar, let def = deviceManager.defaultOutputDevice {
            let maxLen = 14
            let truncated = def.name.count > maxLen ? "\(def.name.prefix(maxLen))…" : def.name
            button.title = " \(truncated)"
        } else {
            button.title = ""
        }
    }

    public func rebuildMenu() {
        statusItem?.menu = MenuBuilder.buildMenu(
            deviceManager: deviceManager,
            volumeManager: volumeManager,
            target: self,
            selectOutputAction: #selector(handleSelectOutput(_:)),
            selectInputAction: #selector(handleSelectInput(_:)),
            openPreferencesAction: #selector(handleOpenPreferences),
            quitAction: #selector(handleQuit)
        )
    }

    @objc private func handleSelectOutput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultOutput(deviceUID: uid)
        pulseStatusItem()
    }

    @objc private func handleSelectInput(_ sender: NSMenuItem) {
        guard let uid = sender.representedObject as? String else { return }
        try? deviceManager.setDefaultInput(deviceUID: uid)
        pulseStatusItem()
    }

    @objc private func handleOpenPreferences() {
        onOpenPreferences?()
    }

    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    public func pulseStatusItem() {
        guard let button = statusItem?.button else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            button.alphaValue = 0.3
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                button.alphaValue = 1.0
            })
        })
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabUI/Menu/
git commit -m "feat(ui): implement VolumeSliderMenuItem, MenuBuilder, and StatusBarController"
```

---

### Task 8: Notification Feedback & Preferences Window

**Files:**
- Create: `Sources/SoundLabUI/Feedback/NotificationDispatcher.swift`
- Create: `Sources/SoundLabUI/Preferences/GeneralPreferencesViewController.swift`
- Create: `Sources/SoundLabUI/Preferences/PreferencesWindowController.swift`

**Interfaces:**
- Consumes: `SoundLabCore.DeviceManager`, `SoundLabCore.SettingsManager`
- Produces:
  - `NotificationDispatcher`: Delivers user notifications when audio device changes.
  - `PreferencesWindowController`: AppKit preferences window with startup, menubar title, and notification toggles.

- [ ] **Step 1: Implement NotificationDispatcher**

```swift
// Sources/SoundLabUI/Feedback/NotificationDispatcher.swift
import Foundation
import UserNotifications
import SoundLabCore

public final class NotificationDispatcher: Sendable {
    private let settingsManager: SettingsManager

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        requestAuthorization()
    }

    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    public func notifyDeviceSwitched(to device: AudioDevice) {
        guard settingsManager.showNotificationBanner else { return }

        let content = UNMutableNotificationContent()
        content.title = "Audio \(device.scope.displayName) Changed"
        content.body = "Active device: \(device.name)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "soundlab.switch.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
```

- [ ] **Step 2: Implement GeneralPreferencesViewController**

```swift
// Sources/SoundLabUI/Preferences/GeneralPreferencesViewController.swift
import AppKit
import ServiceManagement
import SoundLabCore

public final class GeneralPreferencesViewController: NSViewController {
    private let settingsManager: SettingsManager
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch SoundLab at login", target: nil, action: nil)
    private let showTitleCheckbox = NSButton(checkboxWithTitle: "Show active device name in menu bar", target: nil, action: nil)
    private let notificationsCheckbox = NSButton(checkboxWithTitle: "Show banner notification on device switch", target: nil, action: nil)

    public init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 380, height: 160))

        let stack = NSStackView(views: [launchAtLoginCheckbox, showTitleCheckbox, notificationsCheckbox])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])

        launchAtLoginCheckbox.state = settingsManager.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin(_:))

        showTitleCheckbox.state = settingsManager.showDeviceNameInMenuBar ? .on : .off
        showTitleCheckbox.target = self
        showTitleCheckbox.action = #selector(toggleShowTitle(_:))

        notificationsCheckbox.state = settingsManager.showNotificationBanner ? .on : .off
        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(toggleNotifications(_:))
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let isEnabled = (sender.state == .on)
        settingsManager.launchAtLogin = isEnabled

        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("SoundLab: Failed to update login item: \(error)")
            }
        }
    }

    @objc private func toggleShowTitle(_ sender: NSButton) {
        settingsManager.showDeviceNameInMenuBar = (sender.state == .on)
    }

    @objc private func toggleNotifications(_ sender: NSButton) {
        settingsManager.showNotificationBanner = (sender.state == .on)
    }
}
```

- [ ] **Step 3: Implement PreferencesWindowController**

```swift
// Sources/SoundLabUI/Preferences/PreferencesWindowController.swift
import AppKit
import SoundLabCore

public final class PreferencesWindowController: NSWindowController {
    public init(settingsManager: SettingsManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SoundLab Preferences"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = GeneralPreferencesViewController(settingsManager: settingsManager)

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func showPreferences() {
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 4: Build to verify compilation**

Run: `swift build`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabUI/Feedback/ Sources/SoundLabUI/Preferences/
git commit -m "feat(ui): implement NotificationDispatcher and PreferencesWindowController"
```

---

### Task 9: Carbon Global Hotkeys

**Files:**
- Create: `Sources/SoundLabUI/Hotkeys/CarbonHotkeyManager.swift`

**Interfaces:**
- Consumes: `SoundLabCore.DeviceManager`, `SoundLabCore.SettingsManager`, `NotificationDispatcher`
- Produces:
  - `CarbonHotkeyManager`: Registers `⌃⌥⌘Space` (cycle output) and `⌃⌥⌘↓` (cycle input) using Carbon HIToolbox.

- [ ] **Step 1: Implement CarbonHotkeyManager**

```swift
// Sources/SoundLabUI/Hotkeys/CarbonHotkeyManager.swift
import Carbon
import Foundation
import SoundLabCore

public final class CarbonHotkeyManager: @unchecked Sendable {
    private weak var deviceManager: DeviceManager?
    private weak var notificationDispatcher: NotificationDispatcher?
    private let settingsManager: SettingsManager

    private var outputHotKeyRef: EventHotKeyRef?
    private var inputHotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private static var sharedSelf: CarbonHotkeyManager?

    public init(deviceManager: DeviceManager, notificationDispatcher: NotificationDispatcher, settingsManager: SettingsManager) {
        self.deviceManager = deviceManager
        self.notificationDispatcher = notificationDispatcher
        self.settingsManager = settingsManager
    }

    public func registerHotkeys() {
        guard settingsManager.hotkeysEnabled else { return }
        Self.sharedSelf = self

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }

                if hotKeyID.id == 1 {
                    Self.sharedSelf?.handleCycleOutput()
                } else if hotKeyID.id == 2 {
                    Self.sharedSelf?.handleCycleInput()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandler
        )

        // Hotkey 1: Control + Option + Command + Space (Output)
        // Carbon modifier keys: controlKey (4096), optionKey (2048), cmdKey (256)
        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        let spaceKeyCode = UInt32(kVK_Space)
        let outputID = EventHotKeyID(signature: OSType(0x534C4F55), id: 1) // 'SLOU'
        RegisterEventHotKey(spaceKeyCode, modifiers, outputID, GetApplicationEventTarget(), 0, &outputHotKeyRef)

        // Hotkey 2: Control + Option + Command + Down Arrow (Input)
        let downArrowKeyCode = UInt32(kVK_DownArrow)
        let inputID = EventHotKeyID(signature: OSType(0x534C494E), id: 2) // 'SLIN'
        RegisterEventHotKey(downArrowKeyCode, modifiers, inputID, GetApplicationEventTarget(), 0, &inputHotKeyRef)
    }

    private func handleCycleOutput() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            try? self.deviceManager?.cycleNextOutputDevice()
            if let def = self.deviceManager?.defaultOutputDevice {
                self.notificationDispatcher?.notifyDeviceSwitched(to: def)
            }
        }
    }

    private func handleCycleInput() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            try? self.deviceManager?.cycleNextInputDevice()
            if let def = self.deviceManager?.defaultInputDevice {
                self.notificationDispatcher?.notifyDeviceSwitched(to: def)
            }
        }
    }

    public func unregisterHotkeys() {
        if let ref = outputHotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = inputHotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }

    deinit {
        unregisterHotkeys()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `swift build`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add Sources/SoundLabUI/Hotkeys/
git commit -m "feat(ui): implement CarbonHotkeyManager for global keyboard shortcuts"
```

---

### Task 10: App Lifecycle & Entry Point

**Files:**
- Create: `Sources/SoundLabApp/Info.plist`
- Create: `Sources/SoundLabApp/AppDelegate.swift`
- Modify: `Sources/SoundLabApp/main.swift`

**Interfaces:**
- Consumes: All `SoundLabCore` and `SoundLabUI` components
- Produces: Executable `SoundLabApp` wired to `NSApplicationMain` runloop.

- [ ] **Step 1: Write Info.plist**

```xml
<!-- Sources/SoundLabApp/Info.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.atavada.SoundLab</string>
    <key>CFBundleName</key>
    <string>SoundLab</string>
    <key>CFBundleDisplayName</key>
    <string>SoundLab</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>SoundLab inspects audio input device names and scopes to allow switching input sources.</string>
</dict>
</plist>
```

- [ ] **Step 2: Implement AppDelegate**

```swift
// Sources/SoundLabApp/AppDelegate.swift
import AppKit
import SoundLabCore
import SoundLabUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var hardwareService: CoreAudioHardwareService!
    private var settingsManager: SettingsManager!
    private var volumeManager: VolumeManager!
    private var deviceManager: DeviceManager!
    private var deviceObserver: DeviceObserver!
    private var notificationDispatcher: NotificationDispatcher!
    private var statusBarController: StatusBarController!
    private var hotkeyManager: CarbonHotkeyManager!
    private var preferencesWindowController: PreferencesWindowController?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        settingsManager = SettingsManager()
        hardwareService = CoreAudioHardwareService()
        volumeManager = VolumeManager(hardwareService: hardwareService, settingsManager: settingsManager)
        deviceManager = DeviceManager(hardwareService: hardwareService, volumeManager: volumeManager, settingsManager: settingsManager)
        deviceObserver = DeviceObserver(hardwareService: hardwareService, deviceManager: deviceManager)
        notificationDispatcher = NotificationDispatcher(settingsManager: settingsManager)

        try? deviceManager.refreshDevices()
        deviceObserver.startObserving()

        statusBarController = StatusBarController(
            deviceManager: deviceManager,
            volumeManager: volumeManager,
            settingsManager: settingsManager
        )

        statusBarController.onOpenPreferences = { [weak self] in
            self?.openPreferences()
        }

        hotkeyManager = CarbonHotkeyManager(
            deviceManager: deviceManager,
            notificationDispatcher: notificationDispatcher,
            settingsManager: settingsManager
        )
        hotkeyManager.registerHotkeys()

        registerSleepWakeNotifications()
    }

    private func openPreferences() {
        if preferencesWindowController == nil {
            preferencesWindowController = PreferencesWindowController(settingsManager: settingsManager)
        }
        preferencesWindowController?.showPreferences()
    }

    private func registerSleepWakeNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            try? self?.deviceManager.refreshDevices()
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregisterHotkeys()
    }
}
```

- [ ] **Step 3: Implement main.swift**

```swift
// Sources/SoundLabApp/main.swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
```

- [ ] **Step 4: Build executable**

Run: `swift build`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/SoundLabApp/
git commit -m "feat(app): implement AppDelegate and app entry point with sleep-wake listener"
```

---

### Task 11: Packaging Scripts, Makefile & Build Verification

**Files:**
- Create: `scripts/bundle.sh`
- Create: `Makefile`

**Interfaces:**
- Produces: `make bundle` creating `build/SoundLab.app`, ad-hoc signed and runnable.

- [ ] **Step 1: Write bundle.sh**

```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SoundLab"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building SoundLab release executable..."
swift build -c release

echo "Creating application bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

BIN_PATH=$(swift build -c release --show-bin-path)
cp "${BIN_PATH}/SoundLabApp" "${MACOS_DIR}/${APP_NAME}"
cp "Sources/SoundLabApp/Info.plist" "${CONTENTS_DIR}/Info.plist"

echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "Ad-hoc code signing bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Bundle successfully created at ${APP_BUNDLE}"
```

- [ ] **Step 2: Make bundle.sh executable**

Run: `chmod +x scripts/bundle.sh`

- [ ] **Step 3: Write Makefile**

```makefile
.PHONY: all build test bundle run clean

all: bundle

build:
	swift build

test:
	swift test

bundle:
	./scripts/bundle.sh

run: bundle
	open build/SoundLab.app

clean:
	rm -rf .build build
```

- [ ] **Step 4: Execute make test and make bundle**

Run: `make test && make bundle`
Expected: Tests PASS, bundle created at `build/SoundLab.app`

- [ ] **Step 5: Verify App Bundle Structure and Signing**

Run: `codesign -v build/SoundLab.app && ls -la build/SoundLab.app/Contents/MacOS`
Expected: Valid signature, `SoundLab` binary present.

- [ ] **Step 6: Commit**

```bash
git add scripts/ Makefile
git commit -m "chore: add bundle packaging script and Makefile targets"
```

---

### Task 12: Manual Hardware Smoke Test & Verification

- [ ] **Step 1: Launch application bundle**

Run: `open build/SoundLab.app`
Expected: SoundLab menu bar icon appears in macOS menu bar. Zero Dock icon.

- [ ] **Step 2: Verify Audio Device Listing**

Click status bar icon: Output and Input audio devices listed with checkmark on system defaults.

- [ ] **Step 3: Test Device Switching & Volume Memory**

Select alternate output device: Audio routing shifts, volume slider updates to saved level.

- [ ] **Step 4: Test Global Hotkey**

Press `⌃⌥⌘Space`: Next output device selected, notification banner displays.

- [ ] **Step 5: Clean up running test instance**

Run: `pkill -x SoundLab || true`
