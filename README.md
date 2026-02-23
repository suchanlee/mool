# Mool

A local-only macOS screen recorder inspired by Loom. Record your screen, camera, and audio — everything stays on your Mac. No account, no cloud, no internet required.

---

## Features

- **Screen + Camera recording** — full display, specific window, or camera only
- **Floating recording HUD** — non-activating overlay that never steals focus from the app you're recording
- **Draggable camera bubble** — circular webcam overlay, resizable, movable anywhere
- **Live annotations** — draw on screen during recording; cursor highlight, spotlight, and click burst effects
- **Speaker notes** — floating notes panel visible only to you
- **Global keyboard shortcuts** — start, stop, pause, toggle annotation from any app
- **Local library** — browse, preview, rename, and delete recordings via AVPlayer
- **Menu bar app** — lives in the menu bar; icon pulses red while recording

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 Sonoma or later |
| Xcode | 16.0 or later |
| xcodegen | 2.x (`brew install xcodegen`) |
| Swift | 6.0 |

> **Note:** Screen Recording, Camera, Microphone, and optionally Accessibility permissions are required at runtime. The app will guide you through granting them on first launch.

---

## Build & Run

### 1. Clone the repo

```bash
git clone <repo-url>
cd mool
```

### 2. Install xcodegen (if not already installed)

```bash
brew install xcodegen
```

### 3. Generate the Xcode project

```bash
xcodegen generate
```

This reads `project.yml` and produces `Mool.xcodeproj`. Re-run this any time you add or remove source files.

### 4. Open in Xcode and run

```bash
open Mool.xcodeproj
```

Press **⌘R** to build and run, or build from the command line:

```bash
xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build
```

The built app lands in `~/Library/Developer/Xcode/DerivedData/Mool-*/Build/Products/Debug/Mool.app`.

---

## First Launch — Permissions

Mool needs three permissions to function and one optional permission for cursor effects:

| Permission | Required | Purpose |
|---|---|---|
| Screen Recording | Yes | Capture display / window content via ScreenCaptureKit |
| Camera | Yes | Webcam overlay bubble |
| Microphone | Yes | Voice narration audio track |
| Accessibility | Optional | Cursor highlight ring and click burst effects (CGEvent tap) |

On first launch, Mool shows an onboarding sheet that walks you through each permission. You can also grant them manually:

**System Settings → Privacy & Security → [Screen Recording / Camera / Microphone / Accessibility]**

---

## Usage

### Starting a recording

1. Click the **Mool icon** in the menu bar (⏺ circle).
2. Click **Start Recording** — a source picker appears.
3. Choose your recording mode and which display or window to capture.
4. Click **Record**. After the countdown, recording begins and the floating HUD appears.

### During recording

| Action | How |
|---|---|
| Pause / Resume | Click ⏸ in the HUD, or use the keyboard shortcut |
| Stop | Click ⏹ in the HUD, or use the keyboard shortcut |
| Toggle annotation mode | Click ✏️ in the HUD or use the shortcut |
| Draw on screen | Annotation mode on → drag to draw |
| Erase strokes | Switch to eraser tool in the annotation toolbar |
| Move camera bubble | Drag it anywhere on screen |
| Resize camera bubble | Drag the corner resize handle |
| Speaker notes | Open from the menu bar while recording |

### Default keyboard shortcuts

| Action | Shortcut |
|---|---|
| Start / Stop recording | ⌘⇧R |
| Pause / Resume | ⌘⇧P |
| Toggle annotation mode | ⌘⇧A |
| Toggle camera bubble | ⌘⇧C |
| Toggle speaker notes | ⌘⇧N |

Shortcuts are configurable in **Mool → Settings → Shortcuts**.

### Finding your recordings

Recordings are saved to **~/Movies/Mool/** by default (configurable in Settings → Storage).

- Open the **Library** from the menu bar to browse, preview, rename, and delete recordings.
- **Reveal in Finder** is available from the Library toolbar.

---

## Project Structure

```
mool/
├── project.yml              xcodegen configuration
├── docs/
│   ├── ARCHITECTURE.md      System design, component map, data flow
│   └── TODO.md              Task tracking (phases + status)
└── Mool/
    ├── App/                 App entry point + AppDelegate
    ├── Core/
    │   ├── Recording/       ScreenCaptureManager, CameraManager, AudioManager,
    │   │                    VideoWriter, RecordingEngine
    │   ├── Annotation/      AnnotationManager, CursorTracker
    │   ├── Permissions/     PermissionManager
    │   └── Storage/         StorageManager
    ├── Models/              RecordingSession, RecordingSettings, CaptureSource
    ├── UI/
    │   ├── WindowCoordinator.swift
    │   ├── MenuBar/         MenuBarController (NSStatusItem)
    │   ├── Overlays/        ControlPanel, CameraBubble, AnnotationOverlay, SpeakerNotes
    │   ├── Library/         LibraryView
    │   ├── Settings/        SettingsView
    │   └── Onboarding/      PermissionsView
    └── Resources/           Assets, entitlements, Info.plist
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full design document.

---

## Development

### Regenerate Xcode project after adding files

Always run `xcodegen generate` after adding, removing, or moving Swift source files. The `.xcodeproj` is generated from `project.yml` and should not be hand-edited.

### Adding new source files

1. Create the `.swift` file in the appropriate `Mool/` subdirectory.
2. Run `xcodegen generate`.
3. The file is automatically included (xcodegen picks up all `.swift` files under `Mool/`).

### Architecture notes

- **`@Observable`** is used throughout (requires macOS 14+). Do not mix with `ObservableObject`.
- **VideoWriter is not `@MainActor`** — it is called directly from AVFoundation/ScreenCaptureKit capture queues. This avoids per-frame actor hops and is the correct pattern for real-time AVAssetWriter usage.
- **Overlay windows** use `NSPanel` with `.nonactivatingPanel` so they never steal keyboard focus from the app being recorded.

---

## Known Gaps / Roadmap

See [`docs/TODO.md`](docs/TODO.md) for the full task list. High-priority items:

- [ ] App icon artwork (placeholder assets currently)
- [ ] Handle display disconnect mid-recording
- [ ] Keyboard shortcut conflict detection
- [ ] Trim editor
- [ ] Chapter markers
- [ ] Automatic camera framing (Center Stage / face detection)
