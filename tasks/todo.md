# Task Plan

- [x] Inspect countdown target geometry and confirm why overlay sizing is correct but placement is offset.
- [x] Normalize countdown target frames into AppKit window coordinates before creating the overlay.
- [x] Build/test, update docs/tasks/lessons, and record the result.

## Review

- Root cause: countdown target resolution was mixing AppKit screen frames with `SCWindow.frame` / CoreGraphics display geometry. Those use different vertical coordinate origins, so the overlay could have the right size while being vertically misplaced.
- Fix: [`WindowCoordinator.swift`](/Users/suchanlee/code/mool/Mool/UI/WindowCoordinator.swift#L3) now tracks each screen in both AppKit and capture-space coordinates, resolves the selected window against capture-space display bounds, and converts the resulting target into AppKit coordinates before constructing the overlay window.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/CountdownTargetResolverTests test`
  - [x] `CountdownTargetResolverTests`: 3 tests, 0 failures
