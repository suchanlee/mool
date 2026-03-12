# Task Plan

- [x] Inspect the countdown target/overlay code and adapt it from display-only targeting to actual capture-region targeting.
- [x] Implement window-region countdown behavior with focused resolver tests.
- [x] Build/test, update docs/tasks, and record the result.

## Review

- Root cause: after scoping countdown to a single display, window-capture countdown still used that display’s full screen bounds. That matched the chosen monitor but not the user’s requested capture target.
- Fix: evolve `CountdownTargetResolver` in [`WindowCoordinator.swift`](/Users/suchanlee/code/mool/Mool/UI/WindowCoordinator.swift#L3) to return a concrete countdown target frame instead of only a display ID. Display capture still returns the selected display’s frame; window capture now returns the selected `SCWindow.frame`; camera-only returns no target. [`CountdownOverlayWindow`](/Users/suchanlee/code/mool/Mool/UI/Overlays/CountdownOverlayWindow.swift#L14) now accepts an arbitrary frame, so the countdown can render only over the target window region.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/CountdownTargetResolverTests test`
  - [x] `CountdownTargetResolverTests`: 3 tests, 0 failures
