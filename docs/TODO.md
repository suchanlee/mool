# Mool — TODO

Status legend: `[ ]` not started · `[~]` in progress · `[x]` finished

---

## Phase 1 — Project Setup

- [x] Create project documentation (ARCHITECTURE.md, TODO.md)
- [x] Create `project.yml` for xcodegen
- [x] Generate Xcode project via xcodegen
- [x] Configure entitlements (screen recording, camera, mic, accessibility)
- [x] Configure Info.plist (usage descriptions, LSUIElement, login item)
- [x] Set up Assets.xcassets (app icon placeholder)

---

## Phase 2 — Core Models

- [x] `RecordingSession.swift` — runtime state (status, duration, file URL)
- [x] `RecordingSettings.swift` — user preferences (mode, display, quality, shortcuts)
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
- [x] `CameraBubbleWindow.swift` — draggable, resizable borderless NSPanel
- [x] `CameraBubbleView.swift` — SwiftUI camera live preview with drag + corner resize
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
- [x] `WindowCoordinator.swift` — manages all overlay windows, global shortcuts
- [x] `StorageManager.swift` — file management in ~/Movies/Mool/

---

## Phase 8 — Settings UI

- [x] `SettingsView.swift` — tabs: Recording, Shortcuts, Storage, About
- [x] `KeyboardShortcutRecorder.swift` — interactive NSView-based key capture widget
- [x] `ShortcutField.swift` — SwiftUI wrapper for shortcut binding in Settings
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

- [ ] Countdown timer overlay before recording starts (UI countdown in control panel exists; full-screen overlay TBD)
- [x] Menu bar icon animates during recording (red icon when recording)
- [x] True SCStream pause — stopCapture() on pause, resumeCapture() on resume with PTS offset correction
- [x] Multiple display support — display picker in source picker UI
- [x] Window capture mode UI — window picker in source picker UI
- [x] Camera-only mode — exposed via source picker mode selector
- [x] Graceful handling of permission denial (PermissionsView guides user to System Settings)
- [ ] Handle display sleep / disconnect during recording
- [ ] Keyboard shortcut conflict detection
- [x] Recording file auto-named with timestamp

---

## Known Issues / Next Priorities

1. **App Icon** — Placeholder assets only; need actual icon artwork
2. **Accessibility Permission** — `CGEvent.tapCreate` with `.cgAnnotatedSessionEventTap` may need adjustment per macOS version
3. **Display sleep / disconnect** — No graceful handling if the captured display disappears mid-recording
4. **Shortcut conflict detection** — No warning when a user-set shortcut conflicts with system shortcuts
5. **Camera resume gap** — On pause/resume, the camera AVCaptureSession is stopped/started; there may be a brief startup delay before the first frames arrive

---

## Stretch / Future

- [ ] Automatic camera framing (Center Stage / face detection crop)
- [ ] Trim editor (in-app video trim before saving)
- [ ] Chapter markers (click to add timestamp markers during recording)
- [ ] Export to MP4
- [ ] Markdown speaker notes with syntax highlighting
- [ ] Hotkey to snap camera bubble to corners
