# Task Plan

- [x] Inspect the built app bundle and generated project to find why the app was still resolving the generic placeholder icon.
- [x] Fix the project spec so `Assets.xcassets/AppIcon.appiconset` is actually bundled into the app and regenerate the project.
- [x] Update About/menu bar icon lookup to follow the built app bundle icon, then keep the DMG branding flow on the same icon set.
- [x] Rebuild the app and DMG, confirm the icon assets are present in the bundle, and record the result.

## Review

- Root cause: `project.yml` excluded `Resources/Assets.xcassets` from the target file list, and the separate `resources:` stanza was not producing a resources build phase in the generated `.xcodeproj`. As a result, the built `.app` had no `Contents/Resources`, no `Assets.car`, and no `AppIcon.icns`, so both About and the menu bar fell back to the generic placeholder icon.
- Fix: remove the asset-catalog exclusion from `project.yml`, exclude only `Info.plist` and `Mool.entitlements`, regenerate `Mool.xcodeproj`, and switch the app UI to read the icon from the built bundle path via `NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)`. The DMG flow still derives its volume icon from the same `AppIcon.appiconset`.
- Verification:
  - [x] `xcodegen generate`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -derivedDataPath build/DerivedData-icon-fix-clean build`
  - [x] Verified the built app now contains `Contents/Resources/AppIcon.icns` and `Contents/Resources/Assets.car`, and `CFBundleIconName` in the built `Info.plist` is `AppIcon`.
  - [x] `./scripts/build-dmg.sh --skip-xcodegen --clean --derived-data build/DerivedData-dmg-icon-fix-clean --output-dir build/icon-fix-dmg-clean`
