# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0.0-beta.2] - Unreleased

### Added
- **CoreAudio Process Tap Engine**: `@available(macOS 14.2, *)` audio process tap engine using `CATapDescription` and `AudioHardwareCreateProcessTap`.
- **Per-App Volume Sliders**: Menu bar section listing active audio-emitting applications with individual volume sliders (0–100%) and mute toggles.
- **Private Aggregate Device Routing**: Isolated real-time aggregate device routing for tapped processes with drift compensation.
- **Real-Time Safe IOProc DSP**: Lock-free, allocation-free audio processing loop applying per-process volume gain scaling.
- **Process Audio Persistence**: Per-application volume settings stored by Bundle Identifier in `UserDefaults`.
- **Process Lifecycle Tracking**: Automatic tap cleanup when target applications terminate via `NSWorkspace` observation.
- **TCC Permission Handling**: System audio recording permission request flow with `NSAudioCaptureUsageDescription`.

---

## [v1.0.0-beta.1] - 2026-09-15

### Added
- **Device Enumeration & Switching**: One-click default audio output and input device routing via CoreAudio HAL C API.
- **Bidirectional Hardware Volume Sync**: CoreAudio listener on `kAudioDevicePropertyVolumeScalar` to keep menu slider in sync with keyboard volume keys and Control Center without echo loops.
- **Per-Device Volume Memory**: Restores remembered master volume level when switching output devices.
- **Custom Menu Slider**: `VolumeSliderMenuItem` hosting continuous AppKit `NSSlider` with live percentage display and arrow key navigation (`±5%` steps).
- **Global Keyboard Shortcuts**:
  - `⌃⌥⌘Space`: Cycle output devices
  - `⌃⌥⌘↓`: Cycle input devices
  - Implemented via Carbon HIToolbox (`RegisterEventHotKey`) without requiring Accessibility permissions.
- **Dynamic Status Item**: SF Symbol adapting between `headphones` and `speaker.wave.2.fill` based on active output device name. Optional truncated device title in menu bar.
- **Preferences Window**: Tabbed `NSTabViewController` with General, Devices, and Shortcuts tabs.
- **Appearance Mode Override**: Toggle between Follow System, Dark Mode, and Light Mode via `NSApp.appearance`.
- **Launch at Login**: Toggle backed by `SMAppService` on macOS 13+.
- **User Notifications & Pulse**: Subtle menu bar icon pulse and optional `UNUserNotificationCenter` banner on device change.
- **Native App Icon**: High-resolution squircle `AppIcon.icns` with dark equalizer theme.
- **DMG Distribution**: `scripts/package-dmg.sh` and `make dmg` generating compressed, signed disk images.
- **Automated CI**: GitHub Actions workflow targeting macOS 15 runner with Xcode 16 for tests and release packaging.
