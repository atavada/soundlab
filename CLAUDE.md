# SoundLab Development Instructions

## Project Overview
SoundLab is a lightweight macOS menu bar utility for audio input/output device switching and per-device volume persistence.

## Tech Stack & Requirements
- **Language**: Swift 6.0+ (Strict Concurrency enabled)
- **Target**: macOS 11.0+ (`arm64` and `x86_64`)
- **Frameworks**: CoreAudio HAL (C-API), AppKit, Carbon (HIToolbox), UserNotifications, ServiceManagement
- **Package Manager**: Swift Package Manager (SPM) with multi-target layout
- **Agent Type**: Background menu bar utility (`LSUIElement = true`)

## Project Architecture
- `Sources/SoundLabCore/`: Pure Swift CoreAudio HAL wrapper, models, managers, and persistence. AppKit-free, 100% unit-testable.
- `Sources/SoundLabUI/`: AppKit UI components (`NSStatusItem`, custom `NSMenu` with `NSSlider`, `NSWindowController` for Preferences) and Carbon global hotkey manager (`RegisterEventHotKey`).
- `Sources/SoundLabApp/`: Executable entry point (`main.swift`, `AppDelegate.swift`, `Info.plist`).
- `Tests/SoundLabCoreTests/`: Unit test suite using `MockAudioHardwareService`.
- `scripts/bundle.sh`: Packages build artifacts into runnable `build/SoundLab.app` with ad-hoc signing.

## Common Commands
- Build: `swift build`
- Run Tests: `swift test`
- Bundle App: `make bundle` (or `./scripts/bundle.sh`)
- Run App: `make run`
- Clean Artifacts: `make clean`

## Code & Quality Rules
- **Swift Concurrency**: Keep types `Sendable`. Annotate UI controllers with `@MainActor`. Avoid data races.
- **Pure AppKit**: Do not introduce SwiftUI unless explicitly asked.
- **Hardware Abstraction**: Always access CoreAudio through `AudioHardwareServiceProtocol` so logic remains mockable in tests.
- **Comments**: Write no unnecessary comments. Only comment subtle CoreAudio C-API quirks or OS workarounds.
- **Terse Style**: Keep implementations minimal, DRY, and YAGNI.

## Git & Commit Rules
- **NEVER** include `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>` or any AI attribution trailers in commit messages.
- Use concise conventional commit messages: `feat:`, `fix:`, `chore:`, `docs:`, `test:`.
