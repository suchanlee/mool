# Task Plan

- [x] Add draggable playhead scrubbing to the library edit timeline without regressing trim-handle dragging.
- [x] Cover the new playhead drag path with focused tests.
- [x] Re-run targeted tests/build, then update docs/tasks to record the interaction.

## Review

- Change: [`TrimTimelineStrip`](/Users/suchanlee/code/mool/Mool/UI/Library/LibraryView.swift) now renders a draggable playhead grip tied to the existing hairline indicator and routes its drag through [`TrimTimelineMath.scrubTime(...)`](/Users/suchanlee/code/mool/Mool/UI/Library/LibraryView.swift). [`VideoDetailView`](/Users/suchanlee/code/mool/Mool/UI/Library/LibraryView.swift) pauses playback on scrub begin, seeks `AVPlayer` on drag updates, and keeps the scrubbing state from fighting the timer-driven playhead refresh.
- Trim-handle behavior is unchanged: start/end drags still use the existing trim math and update the trim range independently of playhead scrubbing.
- `MoolUITests` in [`project.yml`](/Users/suchanlee/code/mool/project.yml) now keeps local code signing enabled so the generated `MoolUITests-Runner.app` is launchable by Gatekeeper during `xcodebuild test`.
- The Library UI scrub test now chooses a drag destination relative to the current playhead position instead of assuming the playhead always starts near the left edge.
- Verification:
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolTests/TrimHandleDragMathTests test`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' build`
  - [x] `xcodebuild -project Mool.xcodeproj -scheme Mool -destination 'platform=macOS' -only-testing:MoolUITests/LibraryUITests/testEditTrimPlayhead_dragsAndMovesIndicator test`
