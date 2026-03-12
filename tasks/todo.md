# Task Plan

- [x] Inspect countdown overlay/window coordination and confirm why all displays were used.
- [x] Implement target-display-only countdown behavior and add focused coverage for display/window target resolution.
- [x] Build/test, update docs/tasks/lessons, and record the result.

## Review

- Root cause: [`WindowCoordinator.showCountdownOverlay()`](/Users/suchanlee/code/mool/Mool/UI/WindowCoordinator.swift#L322) always iterated `NSScreen.screens`, so the pre-roll overlay was shown on every connected display regardless of the selected display or window capture target.
- Fix: add a small `CountdownTargetResolver` in [`WindowCoordinator.swift`](/Users/suchanlee/code/mool/Mool/UI/WindowCoordinator.swift#L3) that resolves the single display to target. Display capture uses the selected `SCDisplay`; window capture resolves the `NSScreen` with the largest intersection against the selected `SCWindow` frame; camera-only returns no overlay. `CountdownOverlayWindow` now stores the display ID it belongs to so the coordinator can rebuild overlays only when the target display changes.
- Verification:
  - [x] `xcodegen generate`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/CountdownTargetResolverTests test`
  - [x] `CountdownTargetResolverTests`: 3 tests, 0 failures
