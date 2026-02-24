# AGENTS.md — Mool

Instructions for any AI agent working on this codebase. Read this before touching code.

---

## What This Project Is

**Mool** is a local-only macOS screen recorder (Loom alternative). It records screen, webcam, and audio into `.mov` files saved to `~/Movies/Mool/`. No accounts, no cloud, no network.

The authoritative human-readable context document is **`docs/CONTEXT.md`**. Read it in full before making any non-trivial change.

---

## Build

```bash
# Regenerate Xcode project from project.yml (required after adding/removing/moving .swift files)
xcodegen generate

# Build
xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build
```

The project must compile with **zero errors and zero warnings** before any commit.

---

## Codebase Map

| File / Directory | Purpose |
|---|---|
| `project.yml` | xcodegen spec — source of truth for the Xcode project |
| `docs/CONTEXT.md` | Full architecture + patterns + known gaps — read first |
| `docs/ARCHITECTURE.md` | System design, data flows, window architecture |
| `docs/TODO.md` | Task tracking (`[ ]` / `[~]` / `[x]`) |
| `Mool/App/` | App entry point (`MoolApp.swift`) + `AppDelegate.swift` |
| `Mool/Core/Recording/` | `RecordingEngine` (key file), screen/camera/audio managers, `VideoWriter` |
| `Mool/Core/Annotation/` | `AnnotationManager`, `CursorTracker` |
| `Mool/Core/Permissions/` | `PermissionManager` |
| `Mool/Core/Storage/` | `StorageManager` |
| `Mool/Models/` | `RecordingSession`, `RecordingSettings`, `CaptureSource` |
| `Mool/UI/` | All SwiftUI + AppKit UI: overlays, menu bar, library, settings, onboarding |

---

## Critical Rules

### Swift 6 Concurrency

`CMSampleBuffer` and `CVPixelBuffer` are **not `Sendable`**. They must never cross an actor boundary via `Task { @MainActor in ... }`.

- `VideoWriter` is **not `@MainActor`** — it is called directly from AVFoundation/SCStream capture queues. This is correct.
- `ScreenCaptureManagerDelegate` is **non-isolated** — its methods are called on background queues.
- `RecordingEngine` delegate methods use `nonisolated func` and call `videoWriter` directly.
- Properties accessed from both `@MainActor` and capture queues use `nonisolated(unsafe)`.

Do not introduce `Task { @MainActor in ... }` around any sample buffer or pixel buffer.

### SwiftUI Observation

All reactive state uses `@Observable` (macOS 14+). Do not mix with `ObservableObject`.

| Pattern | Correct | Wrong |
|---|---|---|
| Inject | `.environment(obj)` | `.environmentObject(obj)` |
| Read | `@Environment(T.self)` | `@EnvironmentObject` |
| Bind | `@Bindable var x` | `@ObservedObject` |
| Own | `@State var x = MyClass()` | `@StateObject` |

### Naming

- Our custom shortcut type is **`RecordingShortcut`** (not `KeyboardShortcut` — that conflicts with SwiftUI's built-in).

### Overlay Windows

All overlay `NSPanel`/`NSWindow` instances must be created with:
```swift
window.level = .floating
window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
window.isReleasedWhenClosed = false
```

### Settings Persistence

`RecordingSettings` persists via a private `SettingsSnapshot: Codable` inner struct → `UserDefaults["MoolRecordingSettings"]`. When adding a new setting: add a `var` to `RecordingSettings`, add it to `SettingsSnapshot`, update `save()` and `load()`.

---

## Commit Discipline

- Make **one commit per logical change** (feature, bug fix, refactor).
- Commit completed work incrementally as you go; do not leave finished logical changes uncommitted when switching tasks.
- Commit message format: `<type>: <short description>` — types: `feat`, `fix`, `refactor`, `docs`, `chore`.
- Examples: `feat: add countdown full-screen overlay`, `fix: camera resume gap after pause`.
- The project must **build successfully** before every commit.

---

## Documentation Maintenance

After every non-trivial change:
1. Update `docs/TODO.md` — mark tasks `[x]` when complete, add new `[ ]` items as discovered.
2. Update `docs/ARCHITECTURE.md` if structure, data flow, or key decisions change.
3. Update `docs/CONTEXT.md` if new patterns, decisions, or file-level descriptions change.

---

## Known Gaps (next priorities)

See `docs/TODO.md` for full list. Top items:

1. **App icon** — `Assets.xcassets/AppIcon.appiconset` has only `Contents.json`. Need PNG assets at standard macOS sizes.
2. **Display disconnect** — `screenCaptureManagerDidStop` calls `stopRecording()` but shows no user-facing error.
3. **Shortcut conflict detection** — no warning when user-set shortcut conflicts with system shortcuts.
4. **Camera resume gap** — ~300ms freeze in PiP after pause/resume.
5. **Full-screen countdown overlay** — `RecordingState.countdown(secondsRemaining:)` exists but only consumed by the HUD, not a full-screen overlay.
