# SoundLab — Architecture & System Design Specification

## 1. System Overview & Goals
SoundLab is a lightweight macOS menu bar utility for rapid audio input/output device switching and per-device volume persistence. It runs as a background menu bar agent (`LSUIElement = true`) with zero dock clutter and low memory footprint (< 30 MB).

### Primary Capabilities
- Enumerate audio input and output devices via macOS CoreAudio HAL.
- Switch system default output and input audio devices with single click.
- Control system master volume directly from a menu bar slider.
- Persist per-device volume memory in `UserDefaults` (restore level on switch).
- Cycle output and input audio devices globally using Carbon HotKeys (`⌃⌥⌘Space`, `⌃⌥⌘↓`) without requiring Accessibility permissions.
- Provide visual and notification feedback on device routing changes.
- Provide tabbed Preferences window for startup, display, and device memory management.

---

## 2. Technology Stack & Project Structure

### Platform & Tools
- Language: Swift 6.0+ (Strict Concurrency enabled)
- Minimum Deployment Target: macOS 11.0+ (Intel `x86_64` & Apple Silicon `arm64`)
- Build System: Swift Package Manager (SPM) with multi-target layout
- Packaging: Custom bash bundle script producing notarization-ready `SoundLab.app` bundle
- Frameworks: CoreAudio HAL (C API), AppKit, Carbon (HIToolbox), ServiceManagement, UserNotifications

### Repository Layout
```
SoundLab/
├── Package.swift
├── Makefile
├── PRD-SoundLab.md
├── docs/
│   └── superpowers/specs/
│       └── 2026-09-15-soundlab-design.md
├── scripts/
│   ├── build.sh
│   └── bundle.sh
├── Sources/
│   ├── SoundLabCore/
│   │   ├── Models/
│   │   │   ├── AudioDevice.swift
│   │   │   ├── DeviceScope.swift
│   │   │   └── SoundLabAudioError.swift
│   │   ├── CoreAudio/
│   │   │   ├── AudioHardwareServiceProtocol.swift
│   │   │   ├── CoreAudioHardwareService.swift
│   │   │   └── AudioObjectPropertyAddress+Extensions.swift
│   │   ├── Managers/
│   │   │   ├── DeviceManager.swift
│   │   │   ├── VolumeManager.swift
│   │   │   ├── SettingsManager.swift
│   │   │   └── DeviceObserver.swift
│   ├── SoundLabUI/
│   │   ├── Menu/
│   │   │   ├── StatusBarController.swift
│   │   │   ├── MenuBuilder.swift
│   │   │   └── VolumeSliderMenuItem.swift
│   │   ├── Preferences/
│   │   │   ├── PreferencesWindowController.swift
│   │   │   └── GeneralPreferencesViewController.swift
│   │   ├── Hotkeys/
│   │   │   └── CarbonHotkeyManager.swift
│   │   └── Feedback/
│   │       └── NotificationDispatcher.swift
│   └── SoundLabApp/
│       ├── main.swift
│       ├── AppDelegate.swift
│       └── Resources/
│           ├── Info.plist
│           └── AppIcon.icns
└── Tests/
    └── SoundLabCoreTests/
        ├── Mocks/
        │   └── MockAudioHardwareService.swift
        ├── DeviceManagerTests.swift
        ├── VolumeManagerTests.swift
        └── SettingsManagerTests.swift
```

---

## 3. Module Design

### 3.1 `SoundLabCore` (CoreAudio & State)
Pure Swift business logic. Zero AppKit dependency. Fully unit testable on CI.

#### Models
- `DeviceScope`: Enum `input`, `output`, `systemOutput`.
- `AudioDevice`: Struct with `id: AudioDeviceID`, `uid: String`, `name: String`, `scope: DeviceScope`, `isDefault: Bool`.
- `SoundLabAudioError`: Enum covering `deviceNotFound`, `volumeNotSupported`, `halError(OSStatus)`, `propertyFetchFailed(AudioObjectPropertySelector)`.

#### CoreAudio Hardware Abstraction
- `AudioHardwareServiceProtocol`:
  - Enumerate device IDs: `kAudioHardwarePropertyDevices` on `kAudioObjectSystemObject`.
  - Fetch UID: `kAudioDevicePropertyDeviceUID`.
  - Fetch Name: `kAudioObjectPropertyName`.
  - Get/Set Default Device: `kAudioHardwarePropertyDefaultOutputDevice` and `kAudioHardwarePropertyDefaultInputDevice`.
  - Get/Set Volume: `kAudioDevicePropertyVolumeScalar` querying master channel (`kAudioObjectPropertyElementMain`), falling back to channel 1.
  - Listener management: `AudioObjectAddPropertyListenerBlock` / `AudioObjectRemovePropertyListenerBlock`.
- `CoreAudioHardwareService`: Production implementation calling macOS C HAL APIs.
- `MockAudioHardwareService`: Thread-safe mock implementation for unit testing.

#### Managers
- `DeviceManager`:
  - Maintains published lists of input and output `AudioDevice` instances.
  - Exposes `setDefaultOutputDevice(uid:)` and `setDefaultInputDevice(uid:)`.
  - Exposes `cycleNextOutputDevice()` and `cycleNextInputDevice()`.
- `VolumeManager`:
  - Reads and writes master scalar volume (`0.0 ... 1.0`).
  - Publishes current default output volume.
  - Emits volume update callbacks.
- `SettingsManager`:
  - Backed by `UserDefaults.standard`.
  - Stores per-device volume: `"vol_\(deviceUID)" -> Float`.
  - Stores preferences: `launchAtLogin: Bool`, `showDeviceNameInMenuBar: Bool`, `showNotificationBanner: Bool`.
- `DeviceObserver`:
  - Registers HAL property listener for `kAudioHardwarePropertyDevices`.
  - Dispatches device arrival/removal to `DeviceManager` on main thread.

### 3.2 `SoundLabUI` (AppKit Menu, Preferences, Hotkeys)

#### Menu Bar Component
- `StatusBarController`:
  - Manages `NSStatusItem` with `.variableLength`.
  - Updates SF Symbol based on active output device (e.g. headphone vs speaker).
  - Updates title text when `showDeviceNameInMenuBar` is enabled.
- `MenuBuilder`:
  - Generates `NSMenu` dynamically:
    - Output devices section (header, radio checkmark on active device).
    - Output volume slider section (`VolumeSliderMenuItem`).
    - Input devices section (header, radio checkmark on active device).
    - Preferences item (`⌘,`).
    - Quit item (`⌘Q`).
- `VolumeSliderMenuItem`:
  - Custom `NSMenuItem` hosting `NSSlider` (continuous, `0.0 ... 1.0`) and percentage readout.
  - Synchronizes slider position with `VolumeManager`.
  - Handles arrow key stepping (5% increments).

#### Global Hotkeys (`CarbonHotkeyManager`)
- Registers hotkeys via Carbon HIToolbox:
  - `RegisterEventHotKey` + `InstallEventHandler` on `kEventClassKeyboard`.
  - Hotkey 1: `⌃⌥⌘Space` -> `DeviceManager.cycleNextOutputDevice()`.
  - Hotkey 2: `⌃⌥⌘↓` -> `DeviceManager.cycleNextInputDevice()`.
- Zero Accessibility permission dialogs required.

#### User Feedback (`NotificationDispatcher`)
- Triggers `UNUserNotificationCenter` toast banner on device change.
- Pulses status item button alpha (200ms highlight) on switch.

#### Preferences Window (`PreferencesWindowController`)
- Single non-resizable `NSWindow` with toolbar tabs:
  - **General**: Launch at login (`SMAppService` / `SMLoginItemSetEnabled`), show title in menubar, enable banners.
  - **Devices**: Table of registered devices, last saved volume, clear memory button.
  - **Shortcuts**: Active hotkey documentation and disable toggle.

### 3.3 `SoundLabApp` (Lifecycle & App Bundle)
- `main.swift`: Initializes `NSApplication`, assigns `AppDelegate`.
- `AppDelegate`:
  - Sets up `SettingsManager`, `DeviceManager`, `VolumeManager`, `StatusBarController`, and `CarbonHotkeyManager`.
  - Subscribes to `NSWorkspace.willSleepNotification` and `didWakeNotification` to reconcile audio hardware state after wake.
- `Info.plist`:
  - `LSUIElement = true` (Runs as background menu bar agent).
  - `NSMicrophoneUsageDescription` (Required by Apple for input device inspection).
  - `LSMinimumSystemVersion = 11.0`.

---

## 4. Build, Packaging & Tooling

### Swift Package (`Package.swift`)
- Products:
  - Executable: `SoundLabApp`
  - Library: `SoundLabCore`
  - Library: `SoundLabUI`
- Dependencies: Internal target dependencies.
- Swift Language Mode: `v6`.

### Bundle Script (`scripts/bundle.sh`)
1. Executes `swift build -c release`.
2. Creates `build/SoundLab.app/Contents/{MacOS,Resources}`.
3. Copies binary `SoundLabApp` to `Contents/MacOS/SoundLab`.
4. Copies `Info.plist` and `AppIcon.icns` into bundle.
5. Runs ad-hoc codesign: `codesign --force --deep --sign - build/SoundLab.app`.

### Makefile Commands
- `make build`: Compiles all targets via `swift build`.
- `make test`: Runs unit tests via `swift test`.
- `make bundle`: Produces `build/SoundLab.app`.
- `make run`: Builds bundle and launches `SoundLab.app`.
- `make clean`: Removes `.build` and `build/`.

---

## 5. Testing & Verification Plan

### Automated Unit Tests (`Tests/SoundLabCoreTests`)
1. `DeviceManagerTests`:
   - Enumerate output vs input devices.
   - Set default output device updates internal state.
   - Cycle output device wraps around to first device on list end.
2. `VolumeManagerTests`:
   - Volume clamping between `0.0` and `1.0`.
   - Volume change dispatches notification.
3. `SettingsManagerTests`:
   - Per-device volume read/write roundtrip.
   - Missing device UID falls back to default level.

### Manual Hardware Verification
1. Launch `SoundLab.app` on macOS. Verify menu bar icon appears with no Dock icon.
2. Click menu bar icon: Verify output devices match macOS Sound settings.
3. Click different output device: Audio routes immediately, volume restores to saved level, notification banner displays.
4. Drag volume slider: System volume level updates in real time.
5. Press `⌃⌥⌘Space`: Next output device selected and checkmark shifts.
6. Connect external headphones/USB interface: Menu updates automatically without relaunch.
