# Task Plan

- [x] Confirm the crash path when selecting a recording in the Library view and isolate the concrete runtime failure.
- [x] Fix the packaging/runtime root cause with the smallest project change needed.
- [x] Rebuild the app, verify the binary links the required playback framework, and document the result.

## Review

- Root cause: `LibraryView` uses SwiftUI `VideoPlayer`, but the app target in `project.yml` did not link `AVKit.framework`. The installed app at `/Applications/Mool.app/Contents/MacOS/Mool` linked `_AVKit_SwiftUI` and `AVFoundation`, but not `AVKit`, so selecting a recording aborted while SwiftUI tried to instantiate the representable-backed player view.
- Fix: add `AVKit.framework` as an explicit SDK dependency for the `Mool` app target in `project.yml`. No library-view source changes were needed.
- Verification:
  - [x] `otool -L /Applications/Mool.app/Contents/MacOS/Mool` confirmed the crashing installed build did not link `AVKit.framework`.
  - [x] `xcodegen generate`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -derivedDataPath build/DerivedData-library-avkit build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -configuration Release -destination 'platform=macOS' -derivedDataPath build/DerivedData-library-avkit-release build`
  - [x] `otool -L build/DerivedData-library-avkit-release/Build/Products/Release/Mool.app/Contents/MacOS/Mool` now shows `AVKit.framework`, `AVFoundation.framework`, `SwiftUI.framework`, and `_AVKit_SwiftUI.framework`.
