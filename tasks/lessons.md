# Lessons

- When a permission issue affects microphone but not camera on macOS, do not assume both use the same status API. Check whether Apple provides a microphone-specific permission surface such as `AVAudioApplication` before reusing camera logic.
- When behavior differs between an Xcode-launched app and a packaged DMG build, inspect build configuration, signing, and hardened runtime before assuming the runtime code path is solely at fault.
