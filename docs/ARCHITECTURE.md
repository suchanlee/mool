# Mool — Architecture

Mool is a local-only macOS screen recording app inspired by Loom. All recordings stay on-device. No accounts, no cloud upload.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 |
| UI | SwiftUI + AppKit (NSPanel, NSWindow for overlays) |
| Screen capture | ScreenCaptureKit (SCStream) — macOS 12.3+ |
| Camera / mic | AVFoundation (AVCaptureSession) |
| Video encoding | AVAssetWriter (H.264 video, AAC audio) |
| Reactive state | @Observable (Observation framework) |
| Build system | xcodegen → Xcode project |
| Minimum deployment | macOS 14.0 (required for `@Observable`) |

---

## High-Level Component Map

```
MoolApp (SwiftUI App)
  └─ AppDelegate (NSApplicationDelegate)
       ├─ MenuBarController         ← NSStatusItem + quick recorder popover/menu
       ├─ RecordingEngine           ← orchestrates all capture
       │    ├─ ScreenCaptureManager  (ScreenCaptureKit / SCStream)
       │    ├─ CameraManager         (AVCaptureSession)
       │    ├─ AudioManager          (mic + system audio)
       │    └─ VideoWriter           (AVAssetWriter → .mov file)
       ├─ AnnotationManager         ← drawing state + cursor FX
       │    └─ CursorTracker         (CGEvent tap)
       ├─ PermissionManager         ← TCC permissions
       ├─ StorageManager            ← ~/Movies/Mool/
       └─ WindowCoordinator         ← manages overlay NSPanels
            ├─ ControlPanelWindow    (floating HUD)
            ├─ CameraBubbleWindow    (draggable cam preview)
            ├─ AnnotationOverlayWindow (full-screen draw layer)
            ├─ SpeakerNotesWindow    (floating notes)
            └─ CountdownOverlayWindow (full-screen pre-roll splash)
```

---

## Directory Layout

```
Mool/
├── App/
│   ├── MoolApp.swift               SwiftUI @main entry
│   └── AppDelegate.swift           NSApplicationDelegate, owns all singletons
├── UI/
│   └── WindowCoordinator.swift     Manages all overlay NSPanel/NSWindow instances
├── Core/
│   ├── Recording/
│   │   ├── RecordingEngine.swift   Coordinates capture pipeline
│   │   ├── ScreenCaptureManager.swift  SCStream-based screen/window capture
│   │   ├── CameraManager.swift     AVCaptureSession camera preview + feed
│   │   ├── AudioManager.swift      Mic + system audio via SCStream
│   │   └── VideoWriter.swift       AVAssetWriter → .mov output
│   ├── Annotation/
│   │   ├── AnnotationManager.swift Drawing tool state, stroke history
│   │   └── CursorTracker.swift     CGEvent tap for mouse pos + clicks
│   ├── Permissions/
│   │   └── PermissionManager.swift TCC checks/requests for cam/mic/screen
│   └── Storage/
│       └── StorageManager.swift    File management in ~/Movies/Mool/
├── Models/
│   ├── RecordingSession.swift      Runtime state of active recording
│   ├── RecordingSettings.swift     User preferences (mode, display, quality)
│   └── CaptureSource.swift        SCDisplay / SCWindow / SCRunningApp wrappers
├── UI/
│   ├── MenuBar/
│   │   ├── MenuBarController.swift NSStatusItem + quick recorder popover/context menu
│   │   └── QuickRecorderPopoverView.swift Loom-style source/camera/audio quick controls
│   ├── Overlays/
│   │   ├── ControlPanelWindow.swift    NSPanel (floating, non-activating)
│   │   ├── ControlPanelView.swift      SwiftUI HUD: record/pause/stop/timer
│   │   ├── CameraBubbleWindow.swift    Borderless NSPanel, draggable
│   │   ├── CameraBubbleView.swift      SwiftUI cam preview with resize handle
│   │   ├── AnnotationOverlayWindow.swift  Full-screen NSWindow, drawing layer
│   │   ├── SpeakerNotesWindow.swift    Floating notes NSPanel
│   │   └── CountdownOverlayWindow.swift Full-screen countdown splash
│   ├── Library/
│   │   └── LibraryView.swift       Browse + play local recordings
│   ├── Settings/
│   │   └── SettingsView.swift      Prefs: shortcuts, quality, storage path
│   └── Onboarding/
│       └── PermissionsView.swift   Step-by-step permission request UI
└── Resources/
    ├── Assets.xcassets/
    ├── Mool.entitlements
    └── Info.plist
```

---

## Recording Pipeline

```
User clicks menu bar status item
      │
      ├─ Left click → QuickRecorderPopoverView (display/window, camera, mic, system audio)
      │               Popover show/close drives quick preview lifecycle:
      │               open => prepareQuickRecorderContext() + show CameraBubbleWindow
      │               interaction => outside-click monitor keeps bubble interactions active
      │               close => teardownQuickRecorderContext() + hide quick preview bubble
      └─ Right click → context menu
                 │
                 ▼
        RecordingEngine.startRecording()
      │
      ├─ ScreenCaptureManager.startStream()
      │       SCStream → CMSampleBuffer (video frames)
      │       SCStream → CMSampleBuffer (system audio, if enabled)
      │
      ├─ CameraManager.startCapture()
      │       AVCaptureSession → CVPixelBuffer (camera frames)
      │
      ├─ AudioManager.startCapture()
      │       AVCaptureSession → CMSampleBuffer (microphone audio)
      │
      └─ VideoWriter.start()
              Writer output dimensions are matched to SCStream source dimensions
              (screen/window content rect with the same 2x scaling)
              Receives screen video → adapts to AVAssetWriter input
              In screen mode, avoids extra camera compositing so only the on-screen camera bubble is captured
              Receives audio → writes AAC track
              On stop → finishes writing → emits file URL

After a successful recording stops, the menu bar controller opens the Library window automatically.

Countdown behavior:
- `RecordingEngine.state = .countdown(secondsRemaining:)` before capture starts.
- `WindowCoordinator` mirrors this state into per-display `CountdownOverlayWindow` instances.

Disconnect behavior:
- `ScreenCaptureManagerDidStop` triggers `RecordingEngine.stopRecording()`.
- `RecordingEngine` stores a runtime error message.
- `MenuBarController` polls and shows an `NSAlert` to explain the stop reason.
```

### Compositing Strategy

Camera-in-picture is composited **in software** at write time:
- Screen frames come in as `CVPixelBuffer` from SCStream.
- Camera frames come in from `AVCaptureVideoDataOutput`.
- `VideoWriter` blits the camera frame onto a scaled region of the screen frame using `Core Image` / `CVPixelBuffer` drawing before passing to `AVAssetWriterInputPixelBufferAdaptor`.
- This avoids needing a separate GPU composition pass and keeps latency low.

---

## Window Architecture

All overlay windows share these properties:
- `level = .floating` (stays above normal app windows)
- `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]`
- `isReleasedWhenClosed = false`

| Window | Type | Interaction |
|---|---|---|
| ControlPanelWindow | NSPanel, `.nonactivatingPanel` | Click buttons, does NOT steal focus |
| CameraBubbleWindow | NSPanel, borderless | Draggable + resizable via explicit SwiftUI gestures that update panel frame |
| AnnotationOverlayWindow | NSWindow, transparent | Pass-through by default; captures events when drawing mode on |
| SpeakerNotesWindow | NSPanel, `.nonactivatingPanel` | Editable text area |
| CountdownOverlayWindow | NSWindow, borderless | Full-screen dim + large pre-roll countdown number |

---

## Annotation System

- `AnnotationManager` holds an array of `Stroke` (a sequence of `CGPoint` + color + width).
- `AnnotationOverlayWindow` hosts a full-screen transparent `NSView` that redraws on each new point.
- When annotation mode is **off**, `ignoresMouseEvents = true` on the overlay (clicks pass through).
- When annotation mode is **on**, `ignoresMouseEvents = false`; the view captures drag events to draw.
- `CursorTracker` uses `CGEvent.tapCreate` (passive) to:
  - Emit cursor position for the spotlight/highlight ring.
  - Detect mouse-down events for click emphasis bursts.

---

## Permissions

| Permission | Purpose | API |
|---|---|---|
| Screen Recording | SCStream access | `SCShareableContent.getExcludingDesktopWindows` triggers TCC prompt |
| Camera | Camera preview and capture | `AVCaptureDevice.requestAccess(for: .video)` |
| Microphone | Mic audio track | `AVCaptureDevice.requestAccess(for: .audio)` |
| Accessibility | CGEvent tap for cursor tracking | `AXIsProcessTrustedWithOptions` |

---

## Storage

Recordings are saved to `~/Movies/Mool/` by default (user-configurable).

File naming: `Mool_YYYY-MM-DD_HH-mm-ss.mov`

`StorageManager` provides:
- Enumeration of saved recordings (sorted by date)
- Delete, rename, reveal-in-Finder
- Total disk usage computation

---

## State Machine

`RecordingEngine` drives a simple state machine:

```
idle ──startRecording()──▶ countdown ──onCountdownEnd()──▶ recording
recording ──pause()──▶ paused
paused ──resume()──▶ recording
recording / paused ──stop()──▶ finishing ──onWriteComplete()──▶ idle
```

All state is published via `@Observable` so SwiftUI views and overlay panels update reactively.
`WindowCoordinator` also hides overlays on an explicit stop request from the HUD so controls are removed immediately while writer finalization completes.

---

## Keyboard Shortcuts

Default shortcuts (user-configurable in Settings):

| Action | Default |
|---|---|
| Start / Stop recording | ⌘⇧R |
| Pause / Resume | ⌘⇧P |
| Toggle annotation mode | ⌘⇧A |
| Toggle camera bubble | ⌘⇧C |
| Toggle speaker notes | ⌘⇧N |

Implemented via `NSEvent.addGlobalMonitorForEvents(matching: .keyDown)`.

---

## Key Design Decisions

1. **ScreenCaptureKit over AVScreenCapture** — SCStream is the modern, sanctioned API for screen recording on macOS 12.3+. It provides window-level capture, system audio, and better performance than CGWindowListCreateImage polling.

2. **Software PiP compositing** — Keeps the architecture simple. No CALayer/Metal compositor needed for initial implementation. Can be upgraded later.

3. **NSPanel for overlays** — Using `.nonactivatingPanel` ensures the floating HUD never steals focus from the app being recorded.

4. **SwiftUI inside NSPanel** — Overlay panels host `NSHostingView<SomeSwiftUIView>` as their content view, combining AppKit window management with SwiftUI's reactive UI.

5. **Observation-first state** — `RecordingEngine` and settings are `@Observable`; AppKit controllers poll/update UI state with timers where direct SwiftUI observation is not available (menu bar and overlay windows).

6. **Local only** — No networking stack, no auth, no telemetry. All data stays in `~/Movies/Mool/`.

---

## Testing Infrastructure

- Unit and UI test targets are declared in `project.yml`:
  - `MoolTests` (`bundle.unit-test`)
  - `MoolUITests` (`bundle.ui-testing`)
- Capture manager protocols (`ScreenCaptureManaging`, `CameraManaging`, `AudioManaging`) provide DI seams so `RecordingEngine` can be tested with fakes.
- UI tests rely on explicit accessibility identifiers on critical controls (HUD actions and source picker mode/record controls).
- For local/dev testing, test targets disable code-signing and hardened runtime in `project.yml` to avoid Team ID mismatch when loading the UI test bundle.
