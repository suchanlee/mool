# Mool — TODO

Status legend: `[ ]` not started · `[~]` in progress · `[x]` finished

---

## Phase 1 — Project Setup

- [x] Create project documentation (ARCHITECTURE.md, TODO.md)
- [x] Create `project.yml` for xcodegen
- [x] Generate Xcode project via xcodegen
- [x] Configure entitlements (screen recording, camera, mic, accessibility)
- [x] Configure Info.plist (usage descriptions, LSUIElement, login item)
- [x] Set up Assets.xcassets with generated app icon artwork
- [x] Add SwiftFormat + SwiftLint pre-commit hook workflow

---

## Phase 2 — Core Models

- [x] `RecordingSession.swift` — runtime state (status, duration, file URL)
- [x] `RecordingSettings.swift` — user preferences (mode, display, quality, camera/audio options)
- [x] `CaptureSource.swift` — wrapper for SCDisplay / SCWindow / SCRunningApp

---

## Phase 3 — Permissions

- [x] `PermissionManager.swift` — check + request screen, camera, mic, accessibility
- [x] `PermissionsView.swift` — onboarding UI for step-by-step permission grants

---

## Phase 4 — Recording Engine

- [x] `ScreenCaptureManager.swift` — SCStream setup, display/window picker, start/stop
- [x] `CameraManager.swift` — AVCaptureSession for camera, preview layer, mirror toggle
- [x] `AudioManager.swift` — mic capture via AVCaptureSession; system audio via SCStream
- [x] `VideoWriter.swift` — AVAssetWriter compositing screen + camera PiP → .mov
- [x] `RecordingEngine.swift` — state machine coordinating all capture managers

---

## Phase 5 — Overlay Windows

- [x] `ControlPanelWindow.swift` — floating NSPanel (non-activating)
- [x] `ControlPanelView.swift` — SwiftUI HUD: record/pause/stop/timer/mode indicator
- [x] `CameraBubbleWindow.swift` — draggable borderless NSPanel
- [x] `CameraBubbleView.swift` — SwiftUI camera live preview with drag
- [x] `AnnotationOverlayWindow.swift` — full-screen transparent NSWindow for drawing
- [x] `SpeakerNotesWindow.swift` — floating notes panel

---

## Phase 6 — Annotation & Cursor Effects

- [x] `AnnotationManager.swift` — stroke history, tool state (pen, eraser, highlighter)
- [x] `CursorTracker.swift` — CGEvent tap for cursor pos + click detection
- [x] Cursor highlight ring (follows mouse)
- [x] Click emphasis burst animation
- [x] Cursor spotlight (dim screen except around cursor)

---

## Phase 7 — Menu Bar & App Lifecycle

- [x] `MenuBarController.swift` — NSStatusItem, menu with quick actions
- [x] `AppDelegate.swift` — app lifecycle, singleton ownership, login item toggle
- [x] `MoolApp.swift` — SwiftUI @main, stays in menu bar (NSApp.accessory policy)
- [x] `WindowCoordinator.swift` — manages all overlay windows
- [x] `StorageManager.swift` — file management in ~/Movies/Mool/

---

## Phase 8 — Settings UI

- [x] `SettingsView.swift` — tabs: Recording, Storage, About
- [x] Storage path picker + used space display
- [x] Quality picker (720p / 1080p / 4K)
- [x] Countdown timer duration setting
- [x] Auto-launch at login toggle

---

## Phase 9 — Library UI

- [x] `LibraryView.swift` — list of local recordings
- [x] `StorageManager.swift` — enumerate, delete, rename recordings
- [x] Quick Look / AVPlayer preview integration
- [x] Copy file path / reveal in Finder actions

---

## Phase 10 — Polish & Edge Cases

- [x] Countdown timer overlay before recording starts (full-screen splash overlay)
- [x] Menu bar icon animates during recording (red icon when recording)
- [x] Quick recorder camera preview uses camera bubble while popover is open, and fully tears down on close
- [x] Fix cropped display recordings by aligning writer output dimensions with screen stream dimensions
- [x] Restore camera bubble drag behavior in both quick preview and recording sessions
- [x] Keep quick recorder popover open while moving/resizing camera bubble
- [x] Close quick recorder popover on true outside click while preserving status-item/popover/bubble interactions
- [x] Composite camera feed as circular bubble in recorded output (instead of rectangular PiP)
- [x] Ensure screen recordings do not add an extra composited camera bubble beyond the movable on-screen bubble
- [x] Auto-open Library after a recording finishes successfully
- [x] Rework camera bubble drag/resize interaction for 1:1 movement and reliable resize behavior
- [x] Fix Library preview player to switch correctly when a different recording is selected
- [x] Redesign quick recorder popover with rounded row controls and remove top-right utility buttons
- [x] Attach recording HUD below camera bubble and show it only while hovering the bubble/HUD area
- [x] Remove square camera panel outline artifact and use subtle circular bubble shadow styling
- [x] Replace drag-to-resize with HUD camera size presets (Small/Medium/Large)
- [x] True SCStream pause — stopCapture() on pause, resumeCapture() on resume with PTS offset correction
- [x] Multiple display support — display picker in source picker UI
- [x] Window capture mode UI — window picker in source picker UI
- [x] Filter window capture list to app-owned top-level windows only (exclude desktop/system surfaces)
- [x] Camera-only mode — exposed via source picker mode selector
- [x] Graceful handling of permission denial (PermissionsView guides user to System Settings)
- [x] Request screen/camera/microphone permissions on quick recorder popover open (not first at record start)
- [x] Handle display sleep / disconnect during recording (auto-stop + user-facing alert)
- [x] On failed recording start, fully rollback capture state (camera/audio/writer), hide overlays, and return to idle
- [x] Remove global keyboard shortcuts and shortcut settings UI
- [x] Add app icon artwork (abstract water droplet) across all required macOS AppIcon sizes
- [x] Add flip camera support (quick recorder toggle + live mirror apply to preview and camera-only output)
- [x] Recording file auto-named with timestamp

---

## Phase 11 — Testing Infrastructure

- [x] Add protocol-based DI seams for capture managers (`ScreenCaptureManaging`, `CameraManaging`, `AudioManaging`)
- [x] Add `MoolTests` and `MoolUITests` targets in `project.yml`
- [x] Add test fakes for capture managers
- [x] Add unit tests for settings, models, annotation, storage, and engine state
- [x] Add accessibility identifiers used by UI tests
- [x] Add XCUITest suites for launch, library, settings, and source picker flows
- [x] Fix UI test bundle signing mismatch in local/dev builds (disable test target signing + hardened runtime)
- [~] Stabilize flaky XCUITests (status item hit-testing and ambiguous `Settings…` menu item query)

---

## Known Issues / Next Priorities

1. **Accessibility Permission** — `CGEvent.tapCreate` with `.cgAnnotatedSessionEventTap` may need adjustment per macOS version
2. **Camera resume gap** — On pause/resume, the camera AVCaptureSession is stopped/started; there may be a brief startup delay before the first frames arrive
3. **UI test flakiness** — Some XCUITests intermittently fail due status item hit-testing and duplicate `Settings…` menu items in query scope

---

## Stretch / Future

- [ ] Automatic camera framing (Center Stage / face detection crop)
- [ ] Trim editor (in-app video trim before saving)
- [ ] Chapter markers (click to add timestamp markers during recording)
- [ ] Export to MP4
- [ ] Markdown speaker notes with syntax highlighting
- [ ] Hotkey to snap camera bubble to corners
