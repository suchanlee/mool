# Task Plan

- [x] Read the permission docs and inspect the quick-recorder microphone toggle flow.
- [x] Compare microphone and camera toggle behavior and identify why microphone can jump straight to System Settings.
- [x] Update quick-recorder AV toggles to attempt inline permission requests before opening System Settings.
- [x] Add deterministic regression coverage for the quick-toggle permission fallback policy.
- [x] Record verification results and any residual risk.

## Review

- Root cause: the quick-recorder camera and microphone toggles branched on `PermissionManager.refresh()` before attempting `AVCaptureDevice.requestAccess`. If macOS surfaced a stale or already-denied-looking status for a fresh install, the toggle could jump straight to System Settings without ever trying the inline permission prompt path.
- Fix: when a quick-recorder AV toggle is turned on, refresh status for bookkeeping, always attempt the inline request, and only fall back to System Settings if the permission was already `.denied` before that click and the request still failed.
- Verification:
  - [x] `xcodegen generate`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/QuickTogglePermissionResolutionTests test`
- Residual risk: this protects the quick-recorder toggle flow from opening System Settings prematurely, but the actual inline prompt is still controlled by macOS TCC and needs a manual sanity check on a fresh machine to confirm the OS now presents the microphone sheet as expected.
