import XCTest
@testable import Mool

@MainActor
final class RecordingEngineStateTests: XCTestCase {

    var fakeScreen: FakeScreenCaptureManager!
    var fakeCamera: FakeCameraManager!
    var fakeAudio: FakeAudioManager!
    var storage: StorageManager!
    var engine: RecordingEngine!

    override func setUp() async throws {
        try await super.setUp()
        fakeScreen = FakeScreenCaptureManager()
        fakeCamera = FakeCameraManager()
        fakeAudio = FakeAudioManager()
        storage = StorageManager()
        engine = RecordingEngine(
            storageManager: storage,
            cameraManager: fakeCamera,
            screenManager: fakeScreen,
            audioManager: fakeAudio
        )
    }

    // MARK: - Initial state

    func testInitialState_isIdle() {
        XCTAssertEqual(engine.state, .idle)
    }

    func testInitialElapsedTime_isZero() {
        XCTAssertEqual(engine.elapsedTime, 0)
    }

    // MARK: - pauseRecording guards

    func testPauseWhenIdle_stateRemainsIdle() {
        engine.pauseRecording()
        XCTAssertEqual(engine.state, .idle)
    }

    func testPauseWhenIdle_doesNotCallScreenPause() async {
        engine.pauseRecording()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(fakeScreen.pauseCallCount, 0)
    }

    // MARK: - resumeRecording guards

    func testResumeWhenIdle_stateRemainsIdle() {
        engine.resumeRecording()
        XCTAssertEqual(engine.state, .idle)
    }

    func testResumeWhenIdle_doesNotCallScreenResume() async {
        engine.resumeRecording()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(fakeScreen.resumeCallCount, 0)
    }

    // MARK: - stopRecording guards

    func testStopWhenIdle_stateRemainsIdle() async {
        await engine.stopRecording()
        XCTAssertEqual(engine.state, .idle)
    }

    func testStopWhenIdle_doesNotCallScreenStop() async {
        await engine.stopRecording()
        XCTAssertEqual(fakeScreen.stopCallCount, 0)
    }

    // MARK: - pauseRecording from .recording

    func testPauseWhenRecording_stateChangesPaused() {
        engine.state = .recording
        engine.pauseRecording()
        XCTAssertEqual(engine.state, .paused)
    }

    func testPauseWhenRecording_callsScreenPause() async {
        engine.state = .recording
        engine.pauseRecording()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(fakeScreen.pauseCallCount, 1)
    }

    // MARK: - resumeRecording from .paused

    func testResumeWhenPaused_stateChangesRecording() {
        engine.state = .paused
        engine.resumeRecording()
        XCTAssertEqual(engine.state, .recording)
    }

    func testResumeWhenPaused_callsScreenResume() async {
        engine.state = .paused
        engine.resumeRecording()
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(fakeScreen.resumeCallCount, 1)
    }

    // MARK: - stopRecording from .recording

    func testStopWhenRecording_stateGoesToIdle() async {
        engine.state = .recording
        await engine.stopRecording()
        XCTAssertEqual(engine.state, .idle)
    }

    func testStopWhenRecording_callsScreenStop() async {
        engine.state = .recording
        await engine.stopRecording()
        XCTAssertEqual(fakeScreen.stopCallCount, 1)
    }

    func testStopWhenRecording_resetsElapsedTime() async {
        engine.state = .recording
        await engine.stopRecording()
        XCTAssertEqual(engine.elapsedTime, 0)
    }

    // MARK: - stopRecording from .paused

    func testStopWhenPaused_stateGoesToIdle() async {
        engine.state = .paused
        await engine.stopRecording()
        XCTAssertEqual(engine.state, .idle)
    }

    // MARK: - delegate: simulateStop

    func testSimulateStop_whenIdle_stateRemainsIdle() async {
        fakeScreen.simulateStop(error: nil)
        // The delegate call spawns a Task; give it time to run
        await Task.yield()
        await Task.yield()
        XCTAssertEqual(engine.state, .idle)
    }
}
