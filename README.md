# SoundLab

Lightweight, native macOS menu bar utility for audio device switching and per-device volume persistence.

---

## Features

- **One-Click Audio Switching**: Instant toggle between audio output and input devices directly from the macOS status bar.
- **Per-Device Volume Memory**: Automatically remembers last-used volume levels for each connected audio device and restores them upon selection.
- **Bidirectional Volume Sync**: Real-time synchronization with macOS hardware volume changes (keyboard volume keys, touch bar, control center).
- **Global Carbon Hotkeys**: Fast cycling through output devices (`⌃⌥⌘Space`) and input devices (`⌃⌥⌘↓`) without touching mouse.
- **Real-Time Hot-Plug Detection**: Automatically detects connected and disconnected audio hardware using CoreAudio HAL listeners.
- **Polished AppKit Menubar UI**: Custom volume slider item, device category grouping, active device checkmarks, and native notifications.
- **Preferences & System Appearance**: Multi-tab settings panel supporting System, Dark, and Light mode overrides, launch at login toggle, and device default overrides.
- **Zero-Dependency Native Stack**: Pure Swift 6.0 with strict concurrency, built directly against macOS CoreAudio, Carbon, and AppKit APIs.

---

## Requirements

- **macOS**: 11.0 (Big Sur) or higher
- **Architecture**: Universal binary support for Apple Silicon (`arm64`) and Intel (`x86_64`)
- **Toolchain**: Swift 6.0+ (Xcode 16.0+)

---

## Architecture

SoundLab is structured as a modular multi-target Swift package:

```
SoundLab/
├── Sources/
│   ├── SoundLabCore/      # Pure Swift CoreAudio HAL wrapper, models, managers, persistence
│   │   ├── CoreAudio/     # AudioHardwareServiceProtocol & CoreAudioHardwareService (C-HAL)
│   │   ├── Models/        # AudioDevice, DeviceScope, SoundLabAudioError
│   │   └── Managers/      # DeviceManager, VolumeManager, DeviceObserver, SettingsManager
│   ├── SoundLabUI/        # AppKit UI & Carbon event integration
│   │   ├── Menu/          # StatusBarController, MenuBuilder, VolumeSliderMenuItem
│   │   ├── Preferences/   # PreferencesWindowController, Devices/Shortcuts/General VCs
│   │   ├── Hotkeys/       # CarbonHotkeyManager (RegisterEventHotKey)
│   │   └── Feedback/      # NotificationDispatcher (UNUserNotificationCenter)
│   └── SoundLabApp/       # Application entry point & packaging
│       ├── AppDelegate.swift
│       ├── main.swift
│       ├── Info.plist     # LSUIElement = true, NSMicrophoneUsageDescription
│       └── Resources/     # AppIcon.icns
├── Tests/
│   └── SoundLabCoreTests/ # MockAudioHardwareService unit test suite
└── scripts/               # Automation scripts for icon generation, bundling, DMG creation
```

- **SoundLabCore**: AppKit-free, testable audio layer interacting directly with CoreAudio HAL C-APIs (`AudioObjectGetPropertyData`, `AudioObjectSetPropertyData`, `AudioObjectAddPropertyListener`).
- **SoundLabUI**: Pure AppKit UI (`NSStatusItem`, custom `NSMenu`, custom `NSSlider`, `NSWindowController`) and low-level Carbon global hotkey dispatch (`RegisterEventHotKey`).
- **SoundLabApp**: Minimal executable launcher configuring `NSApplication`, `AppDelegate`, sleep/wake system power notifications, and lifecycle management.

---

## Keyboard Shortcuts

| Shortcut | Action | Description |
|---|---|---|
| `⌃⌥⌘Space` (`Ctrl + Opt + Cmd + Space`) | Cycle Output Devices | Cycles default audio output device to the next available device. |
| `⌃⌥⌘↓` (`Ctrl + Opt + Cmd + Down`) | Cycle Input Devices | Cycles default audio input device to the next available device. |
| `⌘,` (`Cmd + ,`) | Open Preferences | Opens the preferences window when the menu bar item is active. |

*Note: Global shortcuts can be toggled on or off in SoundLab Preferences.*

---

## Installation & Build Instructions

### Prerequisites

Ensure Xcode 16+ or Swift 6.0+ Command Line Tools are installed:
```bash
xcode-select --install
swift --version
```

### Build with Swift Package Manager

To build targets in debug mode:
```bash
swift build
```

To run unit tests:
```bash
swift test
```

### Build Application Bundle

Use `make bundle` or `./scripts/bundle.sh` to compile a release binary and package it into an ad-hoc signed application bundle:
```bash
make bundle
```
The output application bundle is created at `build/SoundLab.app`.

To run the application directly:
```bash
make run
```

### Package Distributable Disk Image (DMG)

To package a standalone DMG with a drag-and-drop `/Applications` installer symlink:
```bash
make dmg
```
The compressed disk image is generated at `build/SoundLab-1.0.0.dmg`.

---

## Makefile Targets

| Target | Command | Description |
|---|---|---|
| `make build` | `swift build` | Compiles Swift targets in debug mode. |
| `make test` | `swift test` | Runs unit test suite with mock audio hardware. |
| `make bundle` | `./scripts/bundle.sh` | Compiles release build and creates ad-hoc signed `SoundLab.app`. |
| `make dmg` | `./scripts/package-dmg.sh` | Creates compressed UDZO DMG installer in `build/`. |
| `make icon` | `./scripts/generate-icon.sh` | Generates 1024x1024 master icon and `AppIcon.icns`. |
| `make run` | `open build/SoundLab.app` | Builds bundle and launches app. |
| `make clean` | `rm -rf .build build` | Removes build directories and artifacts. |

---

## License

MIT License. Copyright (c) 2026 Ardhatavada.
