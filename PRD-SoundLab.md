# SoundLab — Product Requirements Document

---

## 1. Title & Meta Information

| Field | Value |
|---|---|
| **Project/Feature Name** | SoundLab |
| **Author** | Ardhatavada |
| **Status** | Draft |
| **Date** | September 2026 |
| **Target Release** | v1.0 — Q4 2026 |
| **Platform** | macOS 11.0+ (Intel & Apple Silicon) |
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
- [ ] All `AVAudioDevice` output devices are listed in the menubar menu
- [ ] Currently active device is marked with a checkmark indicator
- [ ] Clicking a device sets it as the default output immediately
- [ ] Switching feedback is shown (brief menu title update or notification)
- [ ] Input device switching works identically via a separate menu section

### User Story 2: Volume Control
**As a** user who adjusts volume frequently,  
**I want to** control the system volume and have per-device volume memory,  
**So that** each device retains its own preferred volume level.

**Acceptance Criteria:**
- [ ] Volume slider in menubar or preferences adjusts system master volume
- [ ] Each device stores its last-used volume in `UserDefaults`
- [ ] When switching devices, volume jumps to that device's remembered level
- [ ] Volume slider responds to keyboard arrow keys (increment/decrement)
- [ ] Volume changes are reflected in the macOS volume indicator

### User Story 3: Preferences
**As a** user,  
**I want to** open a preferences window to configure basic app settings,  
**So that** I can customize behavior without leaving the app.

**Acceptance Criteria:**
- [ ] Preferences accessible from menubar menu ("Preferences…") or `⌘,`
- [ ] Preferences window includes: default output device, default input device, volume per device, startup behavior
- [ ] "Launch at login" toggle setting
- [ ] Dark mode / Light mode toggle (or follow system)
- [ ] Settings persist across app restarts

### User Story 4: Keyboard Shortcuts
**As a** power user,  
**I want to** cycle through audio devices using a keyboard shortcut,  
**So that** I can switch devices without touching the mouse.

**Acceptance Criteria:**
- [ ] Default shortcut: `⌃⌥⌘Space` to cycle output devices
- [ ] Default shortcut: `⌃⌥⌘↑/↓` to cycle input devices
- [ ] Shortcuts configurable in Preferences
- [ ] Shortcuts work even when app is running in background

### User Story 5: Menubar Experience
**As a** user,  
**I want to** have a clean, informative menubar icon that reflects the current audio state,  
**So that** I always know what's active at a glance.

**Acceptance Criteria:**
- [ ] Menubar icon shows a generic audio/speaker icon by default
- [ ] Icon changes subtly to indicate active device type (speaker, headphone, mic)
- [ ] Menu updates in real-time when devices are plugged/unplugged
- [ ] Menubar shows current device name as title (truncated if too long)

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
├── AppDelegate          → NSApplication delegate, menubar setup
├── StatusBarManager     → NSStatusItem lifecycle, menu construction
├── DeviceManager        → AVAudioDevice enumeration, switching logic
├── VolumeController     → System volume + per-device volume persistence
├── PreferencesManager   → UserDefaults wrapper, settings read/write
├── ShortcutManager      → NSEvent monitor for global keyboard shortcuts
├── DeviceObserver       → NSPointerArray / notifications for hot-plug events
└── PreferencesWindowController → NSWindowController for settings UI
```

### Key Frameworks
| Framework | Usage |
|---|---|
| `AppKit` | UI — menubar, windows, controls |
| `AVFoundation` / `CoreAudio` | `AVAudioDevice` for device enumeration and switching |
| `Foundation` | `UserDefaults`, `NotificationCenter`, data models |
| `ServiceManagement` | Launch at login (`SMLoginItemSetEnabled`) |
| `Carbon` (optional) | Global keyboard event taps for shortcuts |
| `Combine` | Reactive state updates for UI binding |

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
- `NSSpeechRecognitionUsageDescription` — n/a
- `NSMicrophoneUsageDescription` — Required (input device switching)
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
