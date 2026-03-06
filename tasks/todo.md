# Task Plan

- [x] Read project docs and inspect the camera bubble drag path.
- [x] Identify why the first camera bubble drag attempt can be ignored.
- [x] Preserve the AppKit-based drag handling fix in the current working tree.
- [x] Add regression coverage for consecutive single-attempt bubble drags.
- [x] Update project docs to reflect the drag implementation.
- [x] Record verification results and any residual risk.

## Review

- Root cause: the bubble was relying on a SwiftUI `DragGesture` hosted inside a floating non-activating `NSPanel`. On the first attempt, gesture recognition could fail to promote into an actual drag, so the initial mouse interaction often only established focus/interaction state and the second attempt was the first one that moved the panel.
- Fix: use native AppKit window dragging on `CameraBubbleWindow` and keep a custom `NSHostingView` only for first-click delivery and window-move eligibility, so the first mouse-down can immediately begin moving the floating panel.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/CameraBubbleWindowTests test`
- Residual risk: regression coverage is unit-based around frame clamping and move notifications because XCUI interaction with the non-activating floating panel was not deterministic enough to keep as a reliable test.
