# SoundLab — Product Requirements Document

---

## 1. Title & Meta Information

| Field | Value |
|---|---|
| **Project/Feature Name** | SoundLab |
| **Author** | Ardhatavada |
| **Status** | v1.0.0-beta.2 Released |
| **Date** | September 2026 |
| **Target Release** | v1.0.0-beta.2 — September 2026 |
| **Platform** | macOS 11.0+ (Device Switching), macOS 14.2+ (Per-App Volume Mixing) |
| **Language** | Swift 6.0 / AppKit |

---

## 2. Overview & Problem Statement

### What
SoundLab is a lightweight macOS menu bar utility that gives users quick control over their audio devices — switching between output/input devices and adjusting volume — from a single menubar icon, with a polished, dark-mode-first interface.

### Why
macOS exposes audio device switching through a deep System Settings path. Users who frequently switch between headphones, speakers, AirPods, and USB audio interfaces lose time navigating through System Settings each time. SoundLab solves this by putting device switching and volume control directly in the menubar, one click away.

---

## 3. Target Audience & Personas

### Personas

| Persona | Description | Need |
|---|---|---|
| **Content creator** | Records audio/video, switches between mic, headset, and USB interface | Fast input device switching without leaving their workflow |
| **Remote worker** | Jumps between built-in MacBook speakers, external monitor audio, and Bluetooth headphones | One-click output switch during calls vs. media |
| **Audio enthusiast** | Owns multiple audio devices (DAC, amp, powered speakers) | Quick device cycling + granular volume control |
| **Developer (self)** | The builder — wants a clean, extensible codebase | Personal tool, learn Swift + AppKit deeply |

### User Stories (High-Level)
- As a content creator, I want to switch my input device in one click so I don't waste time in System Settings during a recording session.
- As a remote worker, I want to switch output devices instantly so I can move from call audio to media playback seamlessly.
- As an audio enthusiast, I want per-device volume memory so each device remembers its own volume level.

---

## 4. Goals & Non-Goals

### In Scope
- Enumerate all available macOS audio input/output devices
- Switch default audio output device with one click
- Switch default audio input device with one click
- Per-device volume control (master volume per device)
- Volume slider persistence (remember last volume per device)
- Polished menubar UI with dark/light mode support
- Preferences window for basic settings
- Keyboard shortcut support for quick device switching
- Per-application audio volume mixing (`v1.0.0-beta.2`): individual volume sliders (0–100%) and mute toggles for active audio-emitting applications
- CoreAudio Process Tap engine (`v1.0.0-beta.2`): `CATapDescription` with `.mutedWhenTapped` and lock-free real-time DSP gain scaling
- Per-app volume persistence in `UserDefaults` by bundle identifier (`v1.0.0-beta.2`)

### Out of Scope (Non-Goals)
- Audio effects (EQ, boost, compression, reverb)
- Audio recording or monitoring
- Multi-platform support (iOS, iPadOS, watchOS)
- Network/streaming audio routing
- User accounts or multi-user profiles
- App Store distribution — direct download only
- Automation/Shortcuts integration (phase 2+)
- Bluetooth device pairing or management

---

## 5. User Stories & Functional Requirements

### User Story 1: Device Switching
**As a** user who owns multiple audio devices,  
**I want to** see all available output devices in the menubar menu and switch the default output with one click,  
**So that** I don't need to open System Settings each time.

**Acceptance Criteria:**
- [x] All `AVAudioDevice` output devices are listed in the menubar menu
- [x] Currently active device is marked with a checkmark indicator
- [x] Clicking a device sets it as the default output immediately
- [x] Switching feedback is shown (brief menu title update or notification)
- [x] Input device switching works identically via a separate menu section

### User Story 2: Volume Control
**As a** user who adjusts volume frequently,  
**I want to** control the system volume and have per-device volume memory,  
**So that** each device retains its own preferred volume level.

**Acceptance Criteria:**
- [x] Volume slider in menubar or preferences adjusts system master volume
- [x] Each device stores its last-used volume in `UserDefaults`
- [x] When switching devices, volume jumps to that device's remembered level
- [x] Volume slider responds to keyboard arrow keys (increment/decrement)
- [x] Volume changes are reflected in the macOS volume indicator

### User Story 3: Preferences
**As a** user,  
**I want to** open a preferences window to configure basic app settings,  
**So that** I can customize behavior without leaving the app.

**Acceptance Criteria:**
- [x] Preferences accessible from menubar menu ("Preferences…") or `⌘,`
- [x] Preferences window includes: default output device, default input device, volume per device, startup behavior
- [x] "Launch at login" toggle setting
- [x] Dark mode / Light mode toggle (or follow system)
- [x] Settings persist across app restarts

### User Story 4: Keyboard Shortcuts
**As a** power user,  
**I want to** cycle through audio devices using a keyboard shortcut,  
**So that** I can switch devices without touching the mouse.

**Acceptance Criteria:**
- [x] Default shortcut: `⌃⌥⌘Space` to cycle output devices
- [x] Default shortcut: `⌃⌥⌘↑/↓` to cycle input devices
- [x] Shortcuts configurable in Preferences
- [x] Shortcuts work even when app is running in background

### User Story 5: Menubar Experience
**As a** user,  
**I want to** have a clean, informative menubar icon that reflects the current audio state,  
**So that** I always know what's active at a glance.

**Acceptance Criteria:**
- [x] Menubar icon shows a generic audio/speaker icon by default
- [x] Icon changes subtly to indicate active device type (speaker, headphone, mic)
- [x] Menu updates in real-time when devices are plugged/unplugged
- [x] Menubar shows current device name as title (truncated if too long)

### User Story 6: Per-App Volume Mixing (v1.0.0-beta.2)
**As a** user running multiple applications with audio output,  
**I want to** adjust the volume of individual applications or mute them independently in the menubar menu,  
**So that** I can balance audio levels (e.g. lower music while on a call) without changing system master volume.

**Acceptance Criteria:**
- [x] Active audio-emitting applications appear under "Applications" section in menubar menu (macOS 14.2+)
- [x] Each application displays its running icon, display name, volume slider (0–100%), and percentage readout
- [x] Adjusting app volume slider scales process audio gain in real-time
- [x] Audio gain scaling executed via lock-free, allocation-free CoreAudio IOProc callback
- [x] Per-app volume settings persist across app relaunches by bundle identifier in `UserDefaults`
- [x] Terminated applications automatically clean up taps and menu items via `NSWorkspace` observation
- [x] Output device changes seamlessly teardown and rebind taps to active output device

---

## 6. User Experience (UX) & Design

### Core User Flows

#### Flow 1: Switch Output Device
```
User clicks menubar icon
  → Menu expands showing output devices grouped under "Output"
  → Active device shows ✓ checkmark
  → User clicks desired device
  → App calls AVAudioDevice.setPreferredOutput()
  → Menu collapses, icon updates
  → Brief toast notification: "Switched to [Device Name]"
```

#### Flow 2: Adjust Volume
```
User clicks volume icon in menubar (or opens Preferences)
  → Volume slider appears (0–100%)
  → User drags slider or uses arrow keys
  → Volume changes in real-time
  → Release → volume level saved for current device
```

#### Flow 3: Open Preferences
```
User selects "Preferences…" from menubar menu or presses ⌘,
  → Preferences window slides in (sheet or separate window)
  → Tabs: General, Devices, Shortcuts
  → User toggles "Launch at login", assigns shortcuts, sets defaults
  → Close window → settings saved automatically
```

### Design Principles
- **Dark mode first**: Default to dark appearance, with graceful light mode fallback following system setting
- **Minimal chrome**: No redundant menu bars — the menubar IS the primary interface
- **Instant feedback**: Every action (switch, volume change) gets immediate visual confirmation
- **Consistency**: Follow macOS Human Interface Guidelines for menu bars, sheets, and controls

### Key UI Components
| Component | Purpose |
|---|---|
| `NSStatusBar` / `NSStatusItem` | Menubar icon and menu |
| `NSMenu` | Device list dropdown |
| `NSWindow` (Preferences) | Settings panel |
| `NSSlider` | Volume control |
| `NSTableView` or `NSOutlineView` | Device list in preferences |
| `NSVisualEffectView` | Frosted glass background (dark mode) |
| `NSHostingView` (optional) | If SwiftUI views embedded in AppKit |

### Wireframe References
- Menubar menu: similar to Bartender or Rectangle menubar style
- Preferences window: similar to Rectangle or altTab preferences — simple, tabbed, compact
- No custom animations beyond standard macOS sheet presentations

---

## 7. Technical Considerations

### Architecture Overview
```
SoundLab (AppKit)
├── AppDelegate                → NSApplication delegate, menubar setup, lifecycle
├── StatusBarController        → NSStatusItem lifecycle, menu construction
├── MenuBuilder                → Dynamic menu builder (devices, sliders, apps)
├── VolumeSliderMenuItem       → Master volume slider with live percentage & keyboard nav
├── AppVolumeMenuItem          → Per-app volume slider, icon, mute toggle (macOS 14.2+)
├── DeviceManager              → CoreAudio HAL device enumeration and switching
├── VolumeManager              → System volume + per-device volume persistence
├── ProcessAudioMixer          → Orchestration of per-app taps & workspace lifecycle (macOS 14.2+)
├── ProcessTapController       → Lock-free real-time IOProc DSP gain scaling (macOS 14.2+)
├── CoreAudioProcessTapService → CATapDescription & private aggregate device manager (macOS 14.2+)
├── SettingsManager            → UserDefaults wrapper, device & per-app volume persistence
├── CarbonHotkeyManager        → HIToolbox global shortcuts (RegisterEventHotKey)
├── DeviceObserver             → CoreAudio HAL property listeners for hot-plug events
└── PreferencesWindowController→ Tabbed NSWindowController for settings UI
```

### Key Frameworks
| Framework | Usage |
|---|---|
| `AppKit` | UI — menubar, windows, controls |
| `CoreAudio` (HAL) | Device enumeration, switching, property listeners |
| `CoreAudio` (macOS 14.2+) | `CATapDescription`, `AudioHardwareCreateProcessTap` for per-app audio tap |
| `Foundation` | `UserDefaults`, `NotificationCenter`, data models |
| `ServiceManagement` | Launch at login (`SMAppService`) |
| `Carbon` | Global keyboard shortcuts (`RegisterEventHotKey`) |
| `UserNotifications` | Native notification dispatch on device change |

### Data Model
```swift
// Simplified
struct AudioDevice {
    let uid: String          // AVAudioDevice UID
    let name: String         // Display name
    let type: DeviceType     // .input / .output
    let isBuiltin: Bool      // Built-in mic/speaker?
}

struct DeviceSettings {
    let deviceUID: String
    var volume: Float        // 0.0 – 1.0
}

struct AppSettings {
    var launchAtLogin: Bool
    var defaultOutputUID: String?
    var defaultInputUID: String?
    var outputShortcuts: [String: KeyEquivalent]
    var volumePerDevice: [String: Float]
    var darkMode: Bool
}
```

### Persistence
- `UserDefaults.standard` for all settings (simple, sufficient for single-user tool)
- Volume levels stored under device UID keys
- No Core Data, no SQLite — too heavy for this scope

### Permission Requirements
- `NSAudioCaptureUsageDescription` — Required on macOS 14.2+ (System audio recording permission for process audio tap gain scaling)
- `NSMicrophoneUsageDescription` — Required (input device switching and enumeration)
- `NSBluetoothAlwaysUsageDescription` — Required if Bluetooth devices present
- `NSAppleMusicUsageDescription` — n/a
- App must be **notarized** if distributed outside App Store

### Build & Distribution
- Xcode project with manual signing
- Build artifacts: `.app` bundle
- Distribution: direct DMG download (notarized) or GitHub Releases
- No sandboxing required (needs full audio device access)

---

## 8. Dependencies, Risks & Mitigations

### Dependencies
| Dependency | Type | Notes |
|---|---|---|
| macOS 11.0 SDK | System | Minimum deployment target |
| Xcode 16+ | Build tool | Required for Swift 6.0 |
| Core Audio framework | System | AVAudioDevice API |
| ServiceManagement | System | Launch at login API |

### Risks & Mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| `AVAudioDevice.setPreferredOutput` fails silently on some USB interfaces | High | Fallback to `AudioObjectSetPropertyData` (Core Audio C API) as secondary method; show user-friendly error alert |
| Device enumeration doesn't update on hot-plug | Medium | Register for `kAudioHardwarePropertyDevices` notification; poll as fallback every 2 seconds |
| Global keyboard shortcuts conflict with other apps | Medium | Allow full customizability in Preferences; default to less common combos (⌃⌥⌘Space) |
| Volume persistence corrupts (UserDefaults) | Low | Add validation on read; reset to default on invalid data; backup plist |
| Dark mode rendering issues on older macOS | Low | Test on macOS 11, 12, 13, 14; fallback to system appearance if custom theme fails |
| Launch at login fails on macOS updates | Low | Re-register on each app launch; use `SMLoginItemSetEnabled` properly |

### Security Considerations
- App requests microphone permission — must have `NSMicrophoneUsageDescription` in Info.plist with clear explanation
- No data leaves the machine — all processing local
- No network access required
- Global keyboard tap requires Accessibility permissions if used (consider NSEvent monitoring instead to avoid this)

---

## 9. Success Metrics

### Quantitative
| Metric | Target (v1.0) |
|---|---|
| Device switch latency | < 500ms from click to audio routing change |
| App launch time | < 1 second cold start |
| Memory usage | < 30 MB resident |
| Menu render time | < 50ms on device plug event |

### Qualitative
- User can switch devices without looking at the menu after 1 week of use (muscle memory)
- Menubar icon is non-intrusive — doesn't distract during work
- Preferences window is immediately understandable (no tooltip needed)
- App feels "alive" — updates menu in real-time when devices change

### Technical Success
- Compiles cleanly with Swift 6.0, zero warnings
- Passes `swiftlint` with project-configured rules
- Supports macOS 11 through latest release (no deprecated API warnings)
- Code coverage on `DeviceManager` and `VolumeController` ≥ 70%

---

## Appendix

### Delivered Milestones
- **v1.0.0-beta.1** (September 2026): Core audio output/input switching, per-device volume memory, bidirectional volume sync, Carbon hotkeys, dark mode menu bar UI, Preferences window, login item integration, DMG release pipeline.
- **v1.0.0-beta.2** (September 2026): Per-application audio volume mixing (macOS 14.2+), `CATapDescription` with `.mutedWhenTapped`, private aggregate device routing, lock-free real-time IOProc DSP gain scaling, per-app volume persistence in `UserDefaults`, `NSWorkspace` app lifecycle tracking, TCC system audio permission handling.

### Future Enhancements (Phase 2+)
- Audio effects (EQ, bass boost, noise gate)
- Audio recording/monitoring mode
- Shortcuts / Automation integration
- Preset profiles (e.g., "Gaming", "Music", "Video Call" — each loads device + volume combo)
- Widget support (macOS Sonoma+)
- AppleScript / Apple Event support for external automation

### Reference Apps
- SoundSource (Rogue Amoeba) — inspiration for device switching UX
- SwitchAudioSource (open source CLI) — reference for Core Audio switching
- Rectangle / Bartender — reference for menubar app patterns
- altTab — reference for polished menubar utility UI
