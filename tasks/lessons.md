# Lessons

- When a permission issue affects microphone but not camera on macOS, do not assume both use the same status API. Check whether Apple provides a microphone-specific permission surface such as `AVAudioApplication` before reusing camera logic.
- When behavior differs between an Xcode-launched app and a packaged DMG build, inspect build configuration, signing, and hardened runtime before assuming the runtime code path is solely at fault.
- When a built app shows the generic placeholder icon despite an AppIcon set existing, inspect the actual .app bundle for a missing Resources/Assets.car before assuming the runtime API is wrong.
- When an overlay is tied to a selected capture target, do not default to `NSScreen.screens`; resolve the active display from the selected `SCDisplay` or the selected window’s frame so multi-display behavior matches the capture target.
