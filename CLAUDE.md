# SoundLab Development Instructions

## Project Overview
SoundLab is a lightweight macOS menu bar utility for audio input/output device switching, per-device volume persistence, and per-app audio volume mixing (`v1.0.0-beta.2`).

## Tech Stack & Requirements
- **Language**: Swift 6.0+ (Strict Concurrency enabled)
- **Target**: macOS 11.0+ (`arm64` and `x86_64`) for device switching; macOS 14.2+ for CoreAudio Process Tap per-app audio mixing
- **Frameworks**: CoreAudio HAL (C-API), AppKit, Carbon (HIToolbox), UserNotifications, ServiceManagement
- **Package Manager**: Swift Package Manager (SPM) with multi-target layout
- **Agent Type**: Background menu bar utility (`LSUIElement = true`)

## Project Architecture
- `Sources/SoundLabCore/`: Pure Swift CoreAudio HAL wrapper, models, managers, and persistence. AppKit-free, 100% unit-testable.
  - `Sources/SoundLabCore/CoreAudio/`: Device discovery, volume, listeners, HAL wrappers.
  - `Sources/SoundLabCore/ProcessAudio/`: `@available(macOS 14.2, *)` process audio tap (`CATapDescription`), private aggregate device lifecycle, lock-free real-time IOProc gain DSP, and per-app volume memory.
- `Sources/SoundLabUI/`: AppKit UI components (`NSStatusItem`, custom `NSMenu` with `NSSlider`, per-app volume sliders, `NSWindowController` for Preferences) and Carbon global hotkey manager (`RegisterEventHotKey`).
- `Sources/SoundLabApp/`: Executable entry point (`main.swift`, `AppDelegate.swift`, `Info.plist`).
- `Tests/SoundLabCoreTests/`: Unit test suite using `MockAudioHardwareService` and mock process tap fixtures.
- `scripts/`:
  - `scripts/bundle.sh`: Packages build artifacts into runnable `build/SoundLab.app` with ad-hoc signing.
  - `scripts/generate-icon.sh`: Renders squircle `AppIcon.icns`.
  - `scripts/package-dmg.sh`: Generates release `build/SoundLab-1.0.0.dmg`.

## Common Commands
- Build: `swift build`
- Run Tests: `swift test`
- Bundle App: `make bundle`
- Package DMG: `make dmg`
- Generate Icon: `make icon`
- Run App: `make run`
- Clean Artifacts: `make clean`

## Code & Quality Rules
- **Swift Concurrency**: Keep types `Sendable`. Annotate UI controllers with `@MainActor`. Avoid data races.
- **Pure AppKit**: Do not introduce SwiftUI unless explicitly asked.
- **Hardware Abstraction**: Always access CoreAudio through protocols (`AudioHardwareServiceProtocol`, `ProcessTapServiceProtocol`) so logic remains mockable in tests.
- **Real-Time Thread Safety**: IOProc audio callbacks must be lock-free, allocation-free, and I/O-free. See `.claude/rules/audio-realtime.md`.
- **Availability Guards**: Guard process tap APIs with `@available(macOS 14.2, *)`. Gracefully handle older macOS versions.
- **Comments**: Write no unnecessary comments. Only comment subtle CoreAudio C-API quirks or OS workarounds.
- **Terse Style**: Keep implementations minimal, DRY, and YAGNI.

## Git & Commit Rules
- **NEVER** include `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>` or any AI attribution trailers in commit messages.
- Use concise conventional commit messages: `feat:`, `fix:`, `chore:`, `docs:`, `test:`.
