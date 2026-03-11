# Mool — Project Context

This file is the single source of truth for picking up this project. It is written for any model, agent, or human developer joining mid-stream. Read this before touching code.

---

## What Mool Is

A **local-only macOS screen recorder** inspired by Loom. Records screen, webcam, and audio into `.mov` files saved to `~/Movies/Mool/`. No accounts, no cloud, no network stack. The app lives in the macOS menu bar.

**Project path:** `/Users/suchanlee/code/mool`

---

## Build Status

**The project builds cleanly with zero errors.**

```bash
cd /Users/suchanlee/code/mool
xcodegen generate          # regenerate Mool.xcodeproj from project.yml
xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build
```

- **Always run `xcodegen generate` after adding/removing/moving Swift files.** The `.xcodeproj` is derived from `project.yml` and picks up all `.swift` files under `Mool/` automatically.
- Xcode 26.2 / Swift 6.2.3 / macOS 26.2 SDK
- Deployment target: **macOS 14.0** (required for `@Observable` macro)
- DMG packaging helper: `./scripts/build-dmg.sh` (manual release step; not part of pre-commit; derives the mounted volume icon from the app icon set)
- The app icon comes from `Mool/Resources/Assets.xcassets/AppIcon.appiconset`; if `project.yml` changes around resources, regenerate `Mool.xcodeproj` and confirm the built app emits `Contents/Resources/AppIcon.icns` and `Assets.car`.
- Library playback depends on `AVKit.framework` being linked by the app target; if `project.yml` changes around target dependencies, regenerate `Mool.xcodeproj` and confirm the built app binary links `AVKit`.

---

## Repository Layout

```
mool/
├── README.md               User-facing build & usage guide
├── project.yml             xcodegen spec — source of truth for the Xcode project
├── .swiftformat            SwiftFormat configuration
├── .swiftlint.yml          SwiftLint configuration
├── .githooks/pre-commit    Repo-managed git pre-commit hook
├── scripts/                Dev scripts (hook install, quality checks, DMG packaging)
├── Mool.xcodeproj/         Generated — do not hand-edit
├── docs/
│   ├── CONTEXT.md          ← this file
│   ├── ARCHITECTURE.md     Full system design, data flows, window architecture
│   └── TODO.md             Task tracking with per-item status
└── Mool/                   All Swift source
    ├── App/
    │   ├── MoolApp.swift               @main SwiftUI entry; WindowGroup for Library + Settings
    │   └── AppDelegate.swift           NSApplicationDelegate; owns all singletons
    ├── Core/
    │   ├── Recording/
    │   │   ├── RecordingEngine.swift   State machine + pipeline coordinator (KEY FILE)
    │   │   ├── ScreenCaptureManager.swift  SCStream display/window capture
    │   │   ├── CameraManager.swift     AVCaptureSession camera + preview layer
    │   │   ├── AudioManager.swift      AVCaptureSession microphone
    │   │   └── VideoWriter.swift       AVAssetWriter; composites camera PiP onto screen
    │   ├── Annotation/
    │   │   ├── AnnotationManager.swift Stroke state, tool selection, overlay toggle
    │   │   └── CursorTracker.swift     CGEvent tap for mouse pos + click detection
    │   ├── Permissions/
    │   │   └── PermissionManager.swift TCC checks + requests (screen/cam/mic/accessibility)
    │   └── Storage/
    │       └── StorageManager.swift    ~/Movies/Mool/ enumeration + metadata + file ops
    ├── Models/
    │   ├── RecordingSession.swift      Struct: id, startDate, duration, fileURL
    │   ├── RecordingSettings.swift     @Observable class: all user prefs
    │   └── CaptureSource.swift         Enum wrapping SCDisplay / SCWindow; AvailableSources class
    └── UI/
        ├── WindowCoordinator.swift     Owns all overlay NSPanels
        ├── MenuBar/
        │   ├── MenuBarController.swift NSStatusItem with branded logo + recording badge; left-click quick recorder, right-click context menu
        │   └── QuickRecorderPopoverView.swift  Loom-style rounded source/camera/audio quick controls with pill toggles (+ camera flip)
        ├── SourcePicker/
        │   ├── SourcePickerView.swift  Pre-recording SwiftUI sheet (mode/display/window/quality)
        │   └── SourcePickerController.swift  Presents SourcePickerView as NSWindow
        ├── Overlays/
        │   ├── ControlPanelWindow.swift    NSPanel (.nonactivatingPanel) — never steals focus
        │   ├── ControlPanelView.swift      HUD: rec indicator, timer, pause/stop, annotation toolbar
        │   ├── CameraBubbleWindow.swift    Borderless NSPanel; draggable
        │   ├── CameraBubbleView.swift      Circular cam preview hosted inside an AppKit first-click-friendly panel
        │   ├── AnnotationOverlayWindow.swift  Full-screen transparent NSWindow for drawing
        │   ├── SpeakerNotesWindow.swift    Floating notes panel (@AppStorage persisted)
        │   └── CountdownOverlayWindow.swift Full-screen pre-roll countdown splash
        ├── Library/
        │   └── LibraryView.swift       NavigationSplitView; AVKit `VideoPlayer` preview with Edit mode (timeline trim + playback speed) and edited-export save flow
        ├── Settings/
        │   └── SettingsView.swift      TabView: Recording, Storage, About (bundle icon + version metadata)
        └── Onboarding/
            └── PermissionsView.swift   Step-by-step permission grant UI
```

---

## Singleton Ownership Chain

Everything is owned by `AppDelegate` and flows down:

```
AppDelegate
  ├── permissionManager: PermissionManager
  ├── storageManager: StorageManager
  ├── recordingEngine: RecordingEngine(storageManager:)
  │     ├── settings: RecordingSettings      (var — must be var for @Bindable chain)
  │     ├── availableSources: AvailableSources
  │     ├── cameraManager: CameraManager     (public — WindowCoordinator reads previewLayer)
  │     ├── screenManager: ScreenCaptureManager  (private)
  │     ├── audioManager: AudioManager       (private)
  │     └── videoWriter: VideoWriter?        (private, nonisolated(unsafe))
  ├── windowCoordinator: WindowCoordinator(recordingEngine:)
  │     ├── annotationManager: AnnotationManager
  │     ├── cursorTracker: CursorTracker
  │     ├── controlPanelWindow: ControlPanelWindow
  │     ├── cameraBubbleWindow: CameraBubbleWindow
  │     ├── annotationOverlayWindow: AnnotationOverlayWindow
  │     ├── speakerNotesWindow: SpeakerNotesWindow
  │     └── sourcePickerController: SourcePickerController
  └── menuBarController: MenuBarController(engine:coordinator:permissions:openLibraryWindow:openSettingsWindow:)
```

`SwiftUI` scenes (`Library`, `Settings`) receive `recordingEngine` and `storageManager` via `.environment(obj)` (not `.environmentObject` — we use `@Observable`, not `ObservableObject`).

---

## Recording Flow (step by step)

1. User clicks the menu bar item.
2. Entry paths:
   - Left click: `MenuBarController` opens `QuickRecorderPopoverView` for fast source/camera/flip/mic toggles.
     - At app launch, camera/microphone toggles are normalized OFF when permission is `.notDetermined`.
     - On popover open, `MenuBarController` shows the quick preview bubble shell immediately.
     - It prepares quick-recorder context and refreshes `CameraBubbleWindow` once ready.
     - Camera/microphone permissions are requested only when their toggles are turned ON.
     - Quick-recorder camera/microphone toggles always attempt the inline AV permission request first; System Settings is only opened as a fallback when the permission was already denied before that click.
     - Quick-recorder controls are disabled while recording/paused to avoid mutating next-session settings mid-capture.
     - Popover behavior is app-defined so interacting with the camera bubble (move) does not auto-dismiss it.
     - Local/global click monitoring closes the popover on true outside clicks while preserving clicks on status-item, popover content, and camera bubble.
     - When the popover closes, it tears down quick-recorder context and hides that quick preview bubble.
   - Right click: `MenuBarController` opens context menu with actions.
     - `Open Library` / `Settings…` are routed to explicit AppDelegate window presenters (instead of responder-chain selectors) for deterministic behavior from status-menu context.
3. User starts recording from quick recorder or source picker.
   - The entry controller (`MenuBarController` / `SourcePickerController`) refreshes `PermissionManager` first.
   - If screen capture is enabled and permission is not granted, it requests screen permission and opens System Settings when denied.
4. `RecordingEngine.startRecording()`:
   - Refreshes `availableSources` (SCShareableContent enumeration; window list is filtered to app-owned top-level windows)
   - Preflights AV permissions before countdown:
     - Camera permission is requested when camera capture is enabled.
     - Microphone permission is requested when microphone capture is enabled.
   - Runs countdown (if `countdownDuration > 0`)
   - Calls `beginCapture()`:
     - Creates `VideoWriter` with source dimensions aligned to `SCStream` resolution (`contentRect * 2`) → calls `writer.setup()`
     - Configures + starts `ScreenCaptureManager` (display or window)
     - Starts `CameraManager`, hooks `onFrame → videoWriter.updateCameraFrame()`
     - Starts `AudioManager`, hooks `onMicBuffer → videoWriter.appendMicAudio()`
     - Sets `state = .recording`, starts elapsed timer
   - If startup fails at any point, it rolls back partial startup (stops capture sessions, cancels writer, clears session) and returns to `.idle`.
5. `WindowCoordinator` shows recording overlays; during countdown it also shows a full-screen `CountdownOverlayWindow` per display.
   - In camera-including modes, the recording HUD is positioned below the camera bubble and only shown while hovering the bubble/HUD region.
6. `ScreenCaptureManager` delegate callbacks (`nonisolated`) call `videoWriter.appendVideoFrame()` / `appendSystemAudio()` **directly on the capture queue** — no actor hops.
7. User hits Stop → `engine.stopRecording()` → finishes `VideoWriter` → file saved to `~/Movies/Mool/` → `coordinator.hideOverlays()`.
8. When recording finishes successfully and state returns to idle, `MenuBarController` auto-opens Library so the new recording is immediately visible.
8. If capture stops unexpectedly (display/window unavailable), `RecordingEngine` stops recording and exposes a runtime error message consumed by `MenuBarController` (via engine notifications) for a user-facing alert.

---

## Pause/Resume (true SCStream stop/restart)

**Pause:**
1. `state = .paused`, elapsed timer stopped.
2. `videoWriter.pause(at: now)` — records pause start time.
3. `screenManager.pauseCapture()` — calls `stream.stopCapture()`, sets `stream = nil` (retains `savedFilter`).
4. `cameraManager.stopCapture()` + `audioManager.stopCapture()`.

**Resume:**
1. `state = .recording`, elapsed timer restarted.
2. `screenManager.resumeCapture()` — recreates SCStream from `savedFilter`, re-adds outputs, calls `startCapture()`.
3. `cameraManager.startCapture()` + `audioManager.startCapture()`.
4. `videoWriter.resume(at: now)` — computes `totalPausedDuration`, subtracts from all future PTS values so the output file appears seamless.

---

## Swift 6 Concurrency Decisions

This is important to understand before modifying capture/write code.

### The problem
`CMSampleBuffer` and `CVPixelBuffer` are not `Sendable`. SCStream and AVFoundation call their output delegates on background queues. `RecordingEngine` is `@MainActor`. Naively dispatching buffers to `@MainActor` via `Task { @MainActor in ... }` violates Swift 6 strict concurrency.

### The solution
**VideoWriter is not `@MainActor`.** It is called directly from capture queues, which is how `AVAssetWriter` (with `expectsMediaDataInRealTime = true`) is designed to be used.

Key annotations:
| Symbol | Why |
|---|---|
| `nonisolated(unsafe) var videoWriter` on `RecordingEngine` | Read from `nonisolated` delegate methods on capture queue |
| `nonisolated(unsafe) var state` on `RecordingEngine` | Read from capture queue as a best-effort guard (written only on MainActor) |
| `nonisolated(unsafe) var delegate` on `ScreenCaptureManager` | Accessed from `nonisolated` SCStreamOutput callback |
| `nonisolated(unsafe) var onFrame` on `CameraManager` | Set on MainActor, called from AVFoundation capture queue |
| `nonisolated(unsafe) var onMicBuffer` on `AudioManager` | Same as above |
| `nonisolated(unsafe) var eventTap` on `CursorTracker` | Accessed from `deinit` (non-isolated context) |
| `ScreenCaptureManagerDelegate` is non-isolated | Its methods are called on background queues; conforming types use `nonisolated func` |

**Do not add `Task { @MainActor in ... }` wrappers around sample buffer callbacks.** This will cause Swift 6 sendability errors. Keep buffer routing synchronous on the capture queue.

---

## SwiftUI Observation Pattern

All `@Observable` classes — **do not mix with `ObservableObject`**.

| Pattern | Correct | Wrong |
|---|---|---|
| Inject into view | `.environment(obj)` | `.environmentObject(obj)` |
| Read in view | `@Environment(Engine.self) var engine` | `@EnvironmentObject var engine` |
| Two-way binding | `@Bindable var settings: RecordingSettings` | `@ObservedObject var settings` |
| Own in view | `@State var obj = MyClass()` | `@StateObject var obj` |

`RecordingSettings` must be declared `var` (not `let`) on `RecordingEngine` so `@Bindable` can write through the keypath chain to nested properties like `engine.settings.mode`.

---

## Permissions

| Permission | API | Required |
|---|---|---|
| Screen Recording | `CGPreflightScreenCaptureAccess` + `CGRequestScreenCaptureAccess` | Yes |
| Camera | `AVCaptureDevice.requestAccess(for: .video)` | Yes |
| Microphone | `AVAudioApplication.requestRecordPermissionWithCompletionHandler` | Yes |
| Accessibility | `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false])` | Optional (cursor effects) |

Note: use the raw string `"AXTrustedCheckOptionPrompt"` — using the `kAXTrustedCheckOptionPrompt` CFString constant triggers a Swift 6 concurrency warning about shared mutable state.

---

## Settings Persistence

`RecordingSettings` persists to `UserDefaults` under key `"MoolRecordingSettings"` using a private `SettingsSnapshot: Codable` inner struct (needed because `@Observable` classes can't directly conform to `Codable`). Call `settings.save()` any time a setting changes. `RecordingSettings.init()` loads from defaults automatically.

`selectedDisplayIndex` and `selectedWindowID` are **not** persisted (runtime-only). Selected input device IDs (`selectedCameraUniqueID`, `selectedMicrophoneUniqueID`) are persisted.

---

## File Output

- Default location: `~/Movies/Mool/`
- Naming: `Mool_YYYY-MM-DD_HH-mm-ss.mov` (auto-suffixed with `_1`, `_2`, ... on collisions)
- Format: QuickTime `.mov`, H.264 video, AAC audio
- Camera PiP: composited in software via CoreImage at write time (bottom-right, 22% of screen width, circular-ish crop)
- Bitrates: 720p=5Mbps, 1080p=10Mbps, 4K=40Mbps

---

## Window Overlay Rules

All overlay windows share these properties set at creation time:
- `level = .floating`
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `isReleasedWhenClosed = false`

The **AnnotationOverlayWindow** starts with `ignoresMouseEvents = true` (pass-through). `AnnotationManager.isAnnotating` toggles this via the `overlayWindow` weak reference.

The **ControlPanelWindow** uses `.nonactivatingPanel` style mask so clicking its buttons never steals focus from the app being recorded.
In camera-including recording modes, `WindowCoordinator` attaches the control panel below `CameraBubbleWindow` and toggles visibility based on pointer hover over bubble/HUD using scoped mouse-event monitors; while actively dragging the bubble, the HUD is temporarily hidden.
The **CameraBubbleWindow** move behavior is handled by AppKit mouse events on the panel itself, while a custom `NSHostingView` only ensures first-click delivery. The panel updates its frame directly in screen space (1:1 drag feel, reduced jitter, reliable first-drag pickup, visible-frame clamping). Bubble size is set via HUD presets (Small/Medium/Large), and the panel-level square shadow is disabled in favor of circular content shadow styling.

The **CountdownOverlayWindow** is borderless, click-through, and shown on each connected display while `RecordingEngine.state` is `.countdown`.

---

## Current State of Work

### What's done (everything builds)
- Full recording pipeline: screen (SCStream), camera (AVCaptureSession), mic (AVCaptureSession), system audio (SCStream), composited output (AVAssetWriter)
  - Camera-only recordings write camera frames directly into `VideoWriter` to start and drive the session timeline.
- True pause/resume (SCStream stop + restart, PTS correction in VideoWriter)
- All overlay windows (control panel HUD, camera bubble, annotation canvas, speaker notes)
- Annotation tools: pen, eraser, highlighter, cursor highlight ring, click burst, spotlight
- Source picker UI (mode card + display grid + window list)
- Menu bar quick recorder popover (left-click) with display/window, camera preview/device, microphone device, system audio controls
- Quick recorder camera menu includes a live "Flip Camera" toggle (mirrors preview and camera-only captured feed)
- Right-click context menu preserved for library/settings/quit actions
- Library view (AVPlayer preview, duration metadata, unified Edit mode with timeline strip/handles, trim + speed edited export, delete/rename/reveal actions)
  - Trim timeline uses a single high-priority drag gesture that resolves the active handle (start/end) at drag begin, then applies translation-based updates for stable dual-handle dragging.
- Settings (Recording, Storage, About tabs)
- Permissions onboarding view
- Menu bar with red pulsing icon during recording
- Full-screen countdown overlay on all displays during pre-roll
- User-facing runtime alert when selected display/window source disappears mid-recording
- Login-at-launch via `SMAppService`
- Testing infrastructure:
  - `MoolTests` + `MoolUITests` targets in `project.yml`
  - Protocol-based DI seams for capture managers
  - Trim-handle math tests covering both start/end drag clamping and handle-target resolution
  - Fake capture managers for unit tests
  - Unit test suites for settings/models/annotation/storage/engine state
  - XCUITest suites for launch/library/settings/source-picker flows
  - `StatusMenuActionsUITests` covers:
    - right-click status-menu actions (`Open Library`, `Settings…`)
    - quick-recorder Start denied/granted screen-permission behavior via deterministic test-only env overrides

### Known gaps / next priorities
1. **Camera resume gap** — On `resumeRecording()`, the camera `AVCaptureSession` is restarted. There's typically a ~300ms startup delay before the first frames arrive. During this window, the VideoWriter composites with a stale `latestCameraBuffer`. This is visually fine but the PiP may freeze briefly.
2. **UI test flakiness** — UI tests now execute, but some cases are flaky due status item hit-testing and menu-interaction assumptions (left-click now opens quick recorder popover).

### Stretch / future features
- Advanced trim timeline (thumbnail scrubber + draggable handles)
- Chapter markers (timestamp annotations written to file metadata)
- MP4 export (re-encode via `AVAssetExportSession` with `.mp4` preset)
- Automatic camera framing (Center Stage API or Vision face detection crop)
- Markdown speaker notes
- Hotkey to snap camera bubble to screen corners

---

## How to Add a New Feature (checklist)

1. **After adding Swift files:** run `xcodegen generate`.
2. **New `@Observable` class:** inject via `.environment(obj)` in the relevant `Scene` or `NSHostingView`. Read with `@Environment(MyClass.self)`.
3. **New overlay window:** add it to `WindowCoordinator`, set `level = .floating` and `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`.
4. **New setting:** add a `var` to `RecordingSettings`, add it to `SettingsSnapshot`, update `save()` and `load()`.
5. **New capture callback:** keep it `nonisolated`, call the writer or a `nonisolated(unsafe)` callback directly — do not dispatch to `@MainActor` with a sample buffer.
6. **Update docs:** keep `TODO.md` current (`[x]` when done), update `ARCHITECTURE.md` if structure changes, update this file if decisions or patterns change.
