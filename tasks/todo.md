# Task Plan

- [x] Reproduce the library trim bug end-to-end and confirm why the end handle does not drag.
- [x] Fix the trim timeline so the trailing handle is draggable without affecting the start handle path.
- [x] Re-run targeted UI/unit coverage, update docs/tasks/lessons, and record the result.

## Review

- Root cause: [`TrimTimelineStrip`](/Users/suchanlee/code/mool/Mool/UI/Library/LibraryView.swift) was positioning its handles with `offset` inside a gesture host that was never explicitly sized to the full `GeometryReader` width. In SwiftUI, `offset` changes rendering position but does not expand layout or hit-test bounds, so the trailing trim handle could render near the right edge while still falling outside the parent drag region.
- Fix: the trim strip now frames the outer gesture host to the full geometry size before applying the shared drag gesture, keeping the end handle inside the hit region. [`LibraryUITests.swift`](/Users/suchanlee/code/mool/MoolUITests/LibraryUITests.swift) now creates a sample recording, opens Edit mode, and verifies that both the start and end trim handles update their respective labels when dragged.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolUITests/LibraryUITests/testEditTrimStartHandle_dragsAndUpdatesStartLabel -only-testing:MoolUITests/LibraryUITests/testEditTrimEndHandle_dragsAndUpdatesEndLabel test`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/TrimHandleDragMathTests test`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
