# Task Plan

- [x] Trace window-capture startup and confirm why camera bubble output disappears.
- [x] Restore camera compositing for selected-window capture and keep the writer layout aligned with the live bubble.
- [x] Build/test, update docs/tasks/lessons, and record the result.

## Review

- Root cause: [`RecordingEngine.beginCapture()`](/Users/suchanlee/code/mool/Mool/Core/Recording/RecordingEngine.swift#L306) disabled writer-side camera compositing for every `includesScreen` recording. That is correct for full-display capture, where the floating bubble is part of the captured screen, but wrong for `desktopIndependentWindow` capture because ScreenCaptureKit never includes Mool’s overlay window there.
- Fix: selected-window capture now routes camera frames back into [`VideoWriter`](/Users/suchanlee/code/mool/Mool/Core/Recording/VideoWriter.swift) while full-display capture still disables duplicate compositing. [`WindowCoordinator.swift`](/Users/suchanlee/code/mool/Mool/UI/WindowCoordinator.swift#L72) now keeps the writer’s overlay frame synchronized with the live bubble and repositions the bubble onto the active capture target when it would otherwise start completely off-target.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/CountdownTargetResolverTests -only-testing:MoolTests/RecordingEngineStateTests test`
  - [x] `CountdownTargetResolverTests`: 5 tests, 0 failures
  - [x] `RecordingEngineStateTests`: 20 tests, 0 failures
