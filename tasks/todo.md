# Task Plan

- [x] Compare the Xcode-launched app against the DMG-built app at the signing/build-configuration level.
- [x] Verify the runtime microphone path uses the dedicated `AVAudioApplication` API.
- [x] Fix the DMG script so unsigned local builds do not ship with hardened runtime and signed builds preserve entitlements when re-signing.
- [x] Update docs and follow-up notes to reflect the packaging constraint.
- [x] Record verification results and residual risk.

## Review

- Root cause: there were two differences between the working Xcode launch and the failing DMG path. First, microphone permission was still using the wrong macOS API (`AVCaptureDevice` instead of `AVAudioApplication`). Second, `./scripts/build-dmg.sh` was producing an unsigned Release app with hardened runtime enabled, which diverged from the local build path the user confirmed worked.
- Fix: use `AVAudioApplication.recordPermission` and `AVAudioApplication.requestRecordPermission` for microphone status/request/preflight, and make the DMG script disable hardened runtime when no signing identity is provided while preserving entitlements when a signed bundle is re-signed.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests test`
  - [x] `./scripts/build-dmg.sh --skip-xcodegen --clean --derived-data build/DerivedData-dmg-verify --output-dir build/verify-dmg`
  - [x] Verified packaged app signature at `build/verify-dmg/dmg-root/Mool.app`: ad hoc only (`flags=0x2`) and camera/microphone entitlements present.

## Residual Risk

- The remaining uncertainty is macOS TCC behavior on the other machine. Unit tests cannot force a real first-run microphone prompt, so the final proof is reinstalling the rebuilt DMG and toggling microphone once on that machine.
