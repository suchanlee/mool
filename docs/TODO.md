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
- [x] Add `scripts/build-dmg.sh` for manual DMG packaging (optional signing/notarization)

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
- [x] Show recording duration metadata in library list items
- [x] Trim recordings from the library viewer using start/end range export
- [x] Add playback speed controls in the library viewer (0.5x–2.0x)
- [x] Add unified Library Edit mode to apply trim + playback speed and save a new edited version
- [x] Replace trim sheet with timeline editor strip (thumbnail rail + drag handles + save/cancel actions)
- [x] Polish editor layout alignment (uniform control widths/heights) and improve trim handle visibility/drag reliability
- [x] Normalize editor button sizing while keeping full-width aligned controls
- [x] Raise trim handles above timeline track and add live playhead progress indicator with play/pause icon sync
- [x] Fix editor interactions: reliable end-handle dragging and full-surface click targets for play/save/cancel controls
- [x] Align trim outline/handles with timeline height and restore reliable start-handle drag behavior
- [x] Stabilize both trim-handle drags using unified timeline drag routing with explicit start/end handle resolution at drag begin
- [x] Keep the trim timeline gesture host framed to the full strip width so the trailing handle stays inside hit-test bounds

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
- [x] Ensure camera bubble shadow renders as circular-only (no rectangular backing artifact)
- [x] Make recording HUD controls theme-adaptive for both light and dark appearance
- [x] Move bubble shadow to AppKit layer `shadowPath` to eliminate residual rectangular compositing artifacts
- [x] Replace drag-to-resize with HUD camera size presets (Small/Medium/Large)
- [x] True SCStream pause — stopCapture() on pause, resumeCapture() on resume with PTS offset correction
- [x] Multiple display support — display picker in source picker UI
- [x] Window capture mode UI — window picker in source picker UI
- [x] Filter window capture list to app-owned top-level windows only (exclude desktop/system surfaces)
- [x] Camera-only mode — exposed via source picker mode selector
- [x] Graceful handling of permission denial (PermissionsView guides user to System Settings)
- [x] Switch to demand-driven permission prompts: camera/mic prompt on toggle-on, screen prompt on recording start
- [x] Show quick preview bubble immediately on popover open while permission/source setup finishes
- [x] Remove always-on idle polling in menu bar/window coordination (notification-driven updates + scoped hover monitors)
- [x] Handle display sleep / disconnect during recording (auto-stop + user-facing alert)
- [x] On failed recording start, fully rollback capture state (camera/audio/writer), hide overlays, and return to idle
- [x] Remove global keyboard shortcuts and shortcut settings UI
- [x] Refresh app icon artwork (abstract water droplet) across all required macOS AppIcon sizes
- [x] Add flip camera support (quick recorder toggle + live mirror apply to preview and camera-only output)
- [x] Recording file auto-named with timestamp
- [x] Start camera-only recordings from camera frames so AVAssetWriter session always begins correctly
- [x] Prevent recording filename collisions with deterministic suffixing (`_1`, `_2`, ...)
- [x] Keep source picker display/window intent synchronized and persist mode/quality/audio/countdown changes
- [x] Fix cursor tracker event-tap callback ownership to avoid leaking `CGEvent` objects
- [x] Fix trim sheet slider crash (`max stride must be positive`) by seeding valid ranges before first render
- [x] Enforce camera/microphone permission preflight at recording start (covers source picker + quick recorder entry paths)
- [x] Reuse shared AV permission helpers in quick recorder and disable quick controls during active recording states
- [x] Fix onboarding camera/microphone denied flow to open System Settings and refresh status on app re-activation
- [x] Unify screen-recording permission helper usage across quick recorder and source picker start paths
- [x] Prompt camera/microphone permissions before countdown so recording start timing is predictable
- [x] Auto-apply pending quick-recorder camera/mic toggle intents when returning from System Settings after granting permissions
- [x] Prevent repeated camera/microphone System Settings auto-launches from quick toggles once permission state is already denied
- [x] Fix status-item right-click menu actions (`Open Library`, `Settings…`) by deferring window open until menu tracking ends and adding selector fallbacks
- [x] Refresh screen-permission state immediately on start actions (quick recorder + source picker) before deciding whether to open System Settings
- [x] Fix camera bubble so the first drag attempt moves immediately instead of requiring a second try
- [x] Fix quick-recorder microphone/camera toggles to attempt inline AV prompts before falling back to System Settings
- [x] Switch microphone permission checks to `AVAudioApplication` so installed builds use the dedicated record-permission API
- [x] Fix unsigned DMG packaging to disable hardened runtime and preserve entitlements on signed re-signs
- [x] Reuse the existing Mool logo in Settings -> About, the menu bar status item, and the mounted DMG volume
- [x] Fix `project.yml`/generated project so `AppIcon.appiconset` is bundled into builds instead of falling back to the generic placeholder icon
- [x] Fix Library recording selection crash by linking `AVKit.framework` so packaged builds can instantiate `VideoPlayer`
- [x] Prevent the quick recorder popover from re-triggering screen-capture consent by caching screen/window source lists between opens
- [x] Limit the pre-recording countdown overlay to the active capture display instead of every connected screen
- [x] Limit window-capture countdown to the selected window region instead of the entire display
- [x] Fix countdown overlay positioning by converting capture-space geometry into AppKit window coordinates before placement
- [x] Restore camera bubble output for selected-window capture by compositing the live bubble geometry in the writer

---

## Phase 11 — Testing Infrastructure

- [x] Add protocol-based DI seams for capture managers (`ScreenCaptureManaging`, `CameraManaging`, `AudioManaging`)
- [x] Add `MoolTests` and `MoolUITests` targets in `project.yml`
- [x] Add test fakes for capture managers
- [x] Add unit tests for settings, models, annotation, storage, and engine state
- [x] Add trim timeline drag math tests for both start/end handles and handle-target resolution
- [x] Add accessibility identifiers used by UI tests
- [x] Add XCUITest suites for launch, library, settings, and source picker flows
- [x] Fix UI test bundle signing mismatch in local/dev builds (disable test target signing + hardened runtime)
- [~] Stabilize flaky XCUITests (status item hit-testing and ambiguous `Settings…` menu item query)
- [x] Add deterministic right-click status-menu UI test coverage for `Open Library` and `Settings…`
- [x] Add deterministic quick-recorder Start permission UI tests for denied/granted screen-recording flows (with test-only permission/recording hooks)
- [x] Add regression coverage for consecutive single-attempt camera bubble drags
- [x] Add unit coverage for quick-recorder AV toggle permission fallback policy
- [x] Add end-to-end Library trim drag UI coverage for both start and end handles
- [ ] Add deterministic coverage for microphone permission status/request bridging without relying on live TCC prompts

---

## Known Issues / Next Priorities

1. **Accessibility Permission** — `CGEvent.tapCreate` with `.cgAnnotatedSessionEventTap` may need adjustment per macOS version
2. **Camera resume gap** — On pause/resume, the camera AVCaptureSession is stopped/started; there may be a brief startup delay before the first frames arrive
3. **UI test flakiness** — Some XCUITests intermittently fail due status item hit-testing and duplicate `Settings…` menu items in query scope

---

## Stretch / Future

- [ ] Automatic camera framing (Center Stage / face detection crop)
- [ ] Advanced trim timeline (thumbnail scrubber + draggable handles)
- [ ] Chapter markers (click to add timestamp markers during recording)
- [ ] Export to MP4
- [ ] Markdown speaker notes with syntax highlighting
- [ ] Hotkey to snap camera bubble to corners
