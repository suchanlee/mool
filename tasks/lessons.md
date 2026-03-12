# Lessons

- When a permission issue affects microphone but not camera on macOS, do not assume both use the same status API. Check whether Apple provides a microphone-specific permission surface such as `AVAudioApplication` before reusing camera logic.
- When behavior differs between an Xcode-launched app and a packaged DMG build, inspect build configuration, signing, and hardened runtime before assuming the runtime code path is solely at fault.
- When a built app shows the generic placeholder icon despite an AppIcon set existing, inspect the actual .app bundle for a missing Resources/Assets.car before assuming the runtime API is wrong.
- When an overlay is tied to a selected capture target, do not default to `NSScreen.screens`; resolve the active display from the selected `SCDisplay` or the selected window’s frame so multi-display behavior matches the capture target.
- When using `SCWindow.frame` or CoreGraphics display bounds to place AppKit overlay windows, convert from capture-space coordinates into AppKit screen coordinates before doing overlap tests or window placement.
- When deciding whether the camera bubble should be captured from the screen stream or composited in the writer, distinguish full-display capture from `desktopIndependentWindow` capture. Selected-window streams never include Mool’s overlay windows.
