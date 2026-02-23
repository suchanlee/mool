import CoreMedia
@testable import Mool

// MARK: - FakeAudioManager

/// Test double for AudioManaging.
/// Records method calls and allows error injection.
@MainActor
final class FakeAudioManager: AudioManaging {

    private(set) var isRunning: Bool = false

    // MARK: - Recorded state

    var setupCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var capturedMicHandler: ((CMSampleBuffer) -> Void)?

    // MARK: - Error injection

    var setupError: Error?

    // MARK: - Protocol conformance

    func setupSession() throws {
        setupCallCount += 1
        if let e = setupError { throw e }
    }

    func startCapture() {
        startCallCount += 1
        isRunning = true
    }

    func stopCapture() {
        stopCallCount += 1
        isRunning = false
    }

    func setMicHandler(_ handler: ((CMSampleBuffer) -> Void)?) {
        capturedMicHandler = handler
    }
}
