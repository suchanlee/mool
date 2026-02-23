import XCTest
@testable import Mool

final class RecordingSessionTests: XCTestCase {

    // MARK: - RecordingSession

    func testInit_hasUniqueID() {
        let s1 = RecordingSession()
        let s2 = RecordingSession()
        XCTAssertNotEqual(s1.id, s2.id)
    }

    func testInit_defaultDurationIsZero() {
        XCTAssertEqual(RecordingSession().duration, 0)
    }

    func testInit_noFileURL() {
        XCTAssertNil(RecordingSession().fileURL)
    }

    func testInit_hasTitleSet() {
        XCTAssertFalse(RecordingSession().title.isEmpty)
    }

    func testFormattedDuration_zero() {
        var s = RecordingSession()
        s.duration = 0
        XCTAssertEqual(s.formattedDuration, "0:00")
    }

    func testFormattedDuration_lessThanOneMinute() {
        var s = RecordingSession()
        s.duration = 45
        XCTAssertEqual(s.formattedDuration, "0:45")
    }

    func testFormattedDuration_minutes() {
        var s = RecordingSession()
        s.duration = 125 // 2m 5s
        XCTAssertEqual(s.formattedDuration, "2:05")
    }

    func testFormattedDuration_longRecording() {
        var s = RecordingSession()
        s.duration = 3661 // 61m 1s
        XCTAssertEqual(s.formattedDuration, "61:01")
    }

    func testHashable_sameSessionInsertedTwice() {
        let s = RecordingSession()
        var set = Set<RecordingSession>()
        set.insert(s)
        set.insert(s)
        XCTAssertEqual(set.count, 1)
    }

    func testDefaultTitle_containsDateComponents() {
        // Use a fixed date so the test is deterministic
        var comps = DateComponents()
        comps.year = 2025; comps.month = 3; comps.day = 7
        comps.hour = 14; comps.minute = 5; comps.second = 9
        let date = Calendar.current.date(from: comps)!
        let title = RecordingSession.defaultTitle(for: date)
        // Title should contain the date in some recognizable form
        XCTAssertTrue(title.contains("2025"), "Title '\(title)' should contain year")
    }

    // MARK: - RecordingState

    func testRecordingState_equatable_idle() {
        XCTAssertEqual(RecordingState.idle, .idle)
    }

    func testRecordingState_equatable_recording() {
        XCTAssertEqual(RecordingState.recording, .recording)
    }

    func testRecordingState_equatable_paused() {
        XCTAssertEqual(RecordingState.paused, .paused)
    }

    func testRecordingState_equatable_finishing() {
        XCTAssertEqual(RecordingState.finishing, .finishing)
    }

    func testRecordingState_equatable_countdown_sameValue() {
        XCTAssertEqual(RecordingState.countdown(secondsRemaining: 3), .countdown(secondsRemaining: 3))
    }

    func testRecordingState_equatable_countdown_differentValues() {
        XCTAssertNotEqual(RecordingState.countdown(secondsRemaining: 3), .countdown(secondsRemaining: 2))
    }

    func testRecordingState_notEqual_differentCases() {
        XCTAssertNotEqual(RecordingState.idle, .recording)
        XCTAssertNotEqual(RecordingState.recording, .paused)
        XCTAssertNotEqual(RecordingState.paused, .finishing)
    }
}
