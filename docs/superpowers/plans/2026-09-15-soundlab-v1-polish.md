# SoundLab v1.0 Final Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the remaining functional gaps to bring SoundLab to full v1.0 production release readiness: external hardware volume sync, appearance mode override, custom application icon, and DMG distribution packaging.

**Architecture:** Extend CoreAudio hardware listener capabilities to watch `kAudioDevicePropertyVolumeScalar` for bidirectional slider sync, add AppKit appearance overrides in preferences, embed native macOS icon asset, and script a standalone DMG distribution pipeline.

**Tech Stack:** Swift 6.0+, macOS CoreAudio HAL, AppKit, Swift Package Manager, `hdiutil` for DMG packaging.

**Spec:** [docs/superpowers/specs/2026-09-15-soundlab-design.md](docs/superpowers/specs/2026-09-15-soundlab-design.md), [PRD-SoundLab.md](PRD-SoundLab.md)

## Global Constraints
- Target platform: macOS 11.0+ (`arm64` and `x86_64`)
- Swift language mode: Swift 6 with strict concurrency checking
- Background menu bar agent: `LSUIElement = true`
- DO NOT add `Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>` or any AI trailer to git commit messages

---

## File Structure Map

```
SoundLab/
├── Makefile
├── scripts/
│   ├── bundle.sh
│   └── package-dmg.sh
├── Sources/
│   ├── SoundLabCore/
│   │   ├── CoreAudio/
│   │   │   ├── AudioHardwareServiceProtocol.swift
│   │   │   └── CoreAudioHardwareService.swift
│   │   └── Managers/
│   │       ├── SettingsManager.swift
│   │       ├── VolumeManager.swift
│   │       └── DeviceObserver.swift
│   ├── SoundLabUI/
│   │   ├── Preferences/
│   │   │   └── GeneralPreferencesViewController.swift
│   │   └── Menu/
│   │       └── VolumeSliderMenuItem.swift
│   └── SoundLabApp/
│       ├── Resources/
│       │   └── AppIcon.icns
│       └── AppDelegate.swift
└── Tests/
    └── SoundLabCoreTests/
        ├── Mocks/
        │   └── MockAudioHardwareService.swift
        └── VolumeManagerTests.swift
```

---

### Task 1: Bidirectional Hardware Volume Sync (CoreAudio Listener)

**Files:**
- Modify: `Sources/SoundLabCore/CoreAudio/AudioHardwareServiceProtocol.swift`
- Modify: `Sources/SoundLabCore/CoreAudio/CoreAudioHardwareService.swift`
- Modify: `Sources/SoundLabCore/Managers/VolumeManager.swift`
- Modify: `Sources/SoundLabCore/Managers/DeviceObserver.swift`
- Modify: `Tests/SoundLabCoreTests/Mocks/MockAudioHardwareService.swift`
- Modify: `Tests/SoundLabCoreTests/VolumeManagerTests.swift`

**Interfaces:**
- Produces:
  - `AudioHardwareServiceProtocol.addVolumeChangeListener(deviceID:block:) -> AudioHardwareListenerToken`
  - `AudioHardwareServiceProtocol.removeVolumeChangeListener(token:)`
  - Real-time updates dispatched to `VolumeManager` observers when volume changes externally (via keyboard volume keys or Control Center).

- [ ] **Step 1: Write failing test in VolumeManagerTests**

Add test to verify external hardware volume changes trigger `VolumeManager` observers and update saved volume:
```swift
@Test func testExternalVolumeChangeSyncsObservers() throws {
    let mock = MockAudioHardwareService()
    mock.addMockDevice(id: 1, uid: "dev-1", name: "Speakers", scopes: [.output], volume: 0.5)
    mock.defaultOutputID = 1

    let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "ext-vol-\(UUID().uuidString)")!)
    let volumeManager = VolumeManager(hardwareService: mock, settingsManager: settings)

    var notifiedVolume: Float = 0.0
    _ = volumeManager.addVolumeChangeObserver { vol in
        notifiedVolume = vol
    }

    // Trigger mock external hardware change
    try mock.setVolume(0.80, for: 1, scope: .output)
    mock.triggerVolumeChange(for: 1)

    #expect(notifiedVolume == 0.80)
    #expect(settings.getSavedVolume(for: "dev-1") == 0.80)
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL (missing `triggerVolumeChange` / volume listener protocol methods)

- [ ] **Step 3: Update AudioHardwareServiceProtocol and MockAudioHardwareService**

Add volume listener methods:
```swift
// In AudioHardwareServiceProtocol:
func addVolumeChangeListener(deviceID: AudioDeviceID, block: @escaping AudioListenerBlock) throws -> AudioHardwareListenerToken
func removeVolumeChangeListener(token: AudioHardwareListenerToken)
```
Implement in `MockAudioHardwareService` with dictionary `[AudioDeviceID: [AudioHardwareListenerToken: AudioListenerBlock]]` and `triggerVolumeChange(for:)`.

- [ ] **Step 4: Implement in CoreAudioHardwareService**

Register `AudioObjectAddPropertyListenerBlock` for `kAudioDevicePropertyVolumeScalar` on `deviceID` with `kAudioObjectPropertyScopeOutput` and element `kAudioObjectPropertyElementMain`. Remove via `AudioObjectRemovePropertyListenerBlock`.

- [ ] **Step 5: Connect VolumeManager to Observe Active Device Volume**

In `VolumeManager`, maintain active hardware volume listener token. Whenever default output device changes, unregister prior listener and attach to new default output device. Disregard self-initiated volume changes (avoid feedback loops).

- [ ] **Step 6: Run swift test**

Run: `swift test`
Expected: PASS (all tests pass)

- [ ] **Step 7: Commit**

```bash
git add Sources/SoundLabCore/ Tests/SoundLabCoreTests/
git commit -m "feat(core): implement CoreAudio hardware volume listener for external volume sync"
```

---

### Task 2: System Appearance Override in Preferences

**Files:**
- Modify: `Sources/SoundLabCore/Managers/SettingsManager.swift`
- Modify: `Sources/SoundLabUI/Preferences/GeneralPreferencesViewController.swift`
- Modify: `Sources/SoundLabApp/AppDelegate.swift`
- Modify: `Tests/SoundLabCoreTests/SettingsManagerTests.swift`

**Interfaces:**
- Produces:
  - `SettingsManager.appearanceMode`: Enum `.system`, `.dark`, `.light` persisted in `UserDefaults`.
  - Appearance popup in `GeneralPreferencesViewController` dynamically applying `NSApp.appearance`.

- [ ] **Step 1: Write failing test in SettingsManagerTests**

```swift
@Test func testAppearanceModePersistence() {
    let settings = SettingsManager(userDefaults: UserDefaults(suiteName: "app-test-\(UUID().uuidString)")!)
    #expect(settings.appearanceMode == .system)

    settings.appearanceMode = .dark
    #expect(settings.appearanceMode == .dark)

    settings.appearanceMode = .light
    #expect(settings.appearanceMode == .light)
}
```

- [ ] **Step 2: Run test to verify failure**

Run: `swift test`
Expected: FAIL

- [ ] **Step 3: Implement AppearanceMode in SettingsManager**

```swift
public enum AppearanceMode: String, Sendable, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    public var displayName: String {
        switch self {
        case .system: return "Follow System"
        case .dark: return "Dark Mode"
        case .light: return "Light Mode"
        }
    }
}
```
Add `appearanceMode` getter/setter in `SettingsManager`.

- [ ] **Step 4: Add Appearance Selector to GeneralPreferencesViewController**

Add an `NSPopUpButton` labeled "Appearance:" with items: "Follow System", "Dark Mode", "Light Mode".
When selected, set `settingsManager.appearanceMode` and apply to `NSApp.appearance`:
```swift
switch mode {
case .system: NSApp.appearance = nil
case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
case .light: NSApp.appearance = NSAppearance(named: .aqua)
}
```

- [ ] **Step 5: Apply appearance on launch in AppDelegate**

In `AppDelegate.applicationDidFinishLaunching`, call helper to apply saved appearance mode to `NSApp.appearance`.

- [ ] **Step 6: Run swift test and verify UI compilation**

Run: `swift test && swift build`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add Sources/SoundLabCore/ Sources/SoundLabUI/ Sources/SoundLabApp/ Tests/SoundLabCoreTests/
git commit -m "feat(ui): add appearance mode override to preferences and app lifecycle"
```

---

### Task 3: Application Icon Asset Generation & Integration

**Files:**
- Create: `scripts/generate-icon.sh`
- Create: `Sources/SoundLabApp/Resources/AppIcon.icns`
- Modify: `scripts/bundle.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces: Valid `AppIcon.icns` embedded into `SoundLab.app/Contents/Resources/AppIcon.icns` and bound in `Info.plist`.

- [ ] **Step 1: Write script to generate high-resolution AppIcon using CoreGraphics/sips**

Create `scripts/generate-icon.sh` that uses a Swift/AppKit one-liner script to render a dark-mode audio equalizer / speaker icon at 1024x1024, creates an `icon.iconset` directory with all standard resolutions (16x16 up to 512x512@2x), and runs `iconutil -c icns` to output `Sources/SoundLabApp/Resources/AppIcon.icns`.

- [ ] **Step 2: Generate AppIcon.icns**

Run: `chmod +x scripts/generate-icon.sh && ./scripts/generate-icon.sh`
Expected: `Sources/SoundLabApp/Resources/AppIcon.icns` created.

- [ ] **Step 3: Update scripts/bundle.sh and Info.plist**

In `Sources/SoundLabApp/Info.plist`:
Ensure `<key>CFBundleIconFile</key><string>AppIcon</string>` is present.
In `scripts/bundle.sh`:
Copy `Sources/SoundLabApp/Resources/AppIcon.icns` to `${RESOURCES_DIR}/AppIcon.icns` if it exists.

- [ ] **Step 4: Verify icon in build bundle**

Run: `make bundle && ls -la build/SoundLab.app/Contents/Resources/AppIcon.icns`
Expected: File exists and is non-empty.

- [ ] **Step 5: Commit**

```bash
git add scripts/ Sources/SoundLabApp/
git commit -m "feat(app): generate and package native AppIcon.icns into app bundle"
```

---

### Task 4: DMG Packaging Script & Release Target

**Files:**
- Create: `scripts/package-dmg.sh`
- Modify: `Makefile`

**Interfaces:**
- Produces: `build/SoundLab-1.0.0.dmg` ready for distribution with `/Applications` drag-and-drop symlink.

- [ ] **Step 1: Write scripts/package-dmg.sh**

Create script with:
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SoundLab"
VERSION="1.0.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="build"
DMG_STAGE="${BUILD_DIR}/dmg-staging"

./scripts/bundle.sh

rm -rf "${DMG_STAGE}" "${BUILD_DIR}/${DMG_NAME}"
mkdir -p "${DMG_STAGE}"

cp -R "${BUILD_DIR}/${APP_NAME}.app" "${DMG_STAGE}/"
ln -s /Applications "${DMG_STAGE}/Applications"

hdiutil create -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGE}" \
  -ov -format UDZO \
  "${BUILD_DIR}/${DMG_NAME}"

rm -rf "${DMG_STAGE}"
echo "DMG successfully created at ${BUILD_DIR}/${DMG_NAME}"
```

- [ ] **Step 2: Make executable and add Makefile target**

Run: `chmod +x scripts/package-dmg.sh`
Add to `Makefile`:
```makefile
dmg: bundle
	./scripts/package-dmg.sh
```

- [ ] **Step 3: Execute make dmg and verify output**

Run: `make dmg`
Expected: `build/SoundLab-1.0.0.dmg` created with valid volume structure.

- [ ] **Step 4: Commit**

```bash
git add scripts/package-dmg.sh Makefile
git commit -m "chore: add DMG distribution packaging script and Makefile target"
```

---

### Task 5: End-to-End Verification & Documentation Update

**Files:**
- Modify: `PRD-SoundLab.md` (Update Status from Draft to Complete v1.0)
- Modify: `README.md` (Create project overview, build instructions, shortcuts guide)

- [ ] **Step 1: Run complete test suite and bundle build**

Run: `make test && make bundle && make dmg`
Expected: 100% tests pass, bundle signed, DMG created.

- [ ] **Step 2: Update PRD-SoundLab.md**

Check off all v1.0 acceptance criteria in `PRD-SoundLab.md`.

- [ ] **Step 3: Write README.md**

Document features, installation, shortcuts (`⌃⌥⌘Space`, `⌃⌥⌘↓`), and build steps.

- [ ] **Step 4: Commit**

```bash
git add PRD-SoundLab.md README.md
git commit -m "docs: finalize v1.0 documentation and acceptance criteria"
```
