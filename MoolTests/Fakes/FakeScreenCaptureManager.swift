import CoreMedia
import ScreenCaptureKit
@testable import Mool

// MARK: - FakeScreenCaptureManager

/// Test double for ScreenCaptureManaging.
/// Records method calls and allows error injection and delegate simulation.
@MainActor
final class FakeScreenCaptureManager: ScreenCaptureManaging {

    weak var delegate: (any ScreenCaptureManagingDelegate)?

    // MARK: - Recorded state

    var configuredForDisplay: SCDisplay?
    var configuredForWindow: SCWindow?
    var startCallCount = 0
    var stopCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0

    // MARK: - Error injection

    var startError: Error?
    var stopError: Error?

    // MARK: - Protocol conformance

    func configureForDisplay(
        _ display: SCDisplay,
        excludingWindows: [SCWindow],
        captureSystemAudio: Bool
    ) async throws {
        configuredForDisplay = display
    }

    func configureForWindow(_ window: SCWindow, captureSystemAudio: Bool) async throws {
        configuredForWindow = window
    }

    func startCapture() async throws {
        startCallCount += 1
        if let e = startError { throw e }
    }

    func stopCapture() async throws {
        stopCallCount += 1
        if let e = stopError { throw e }
    }

    func pauseCapture() async throws {
        pauseCallCount += 1
    }

    func resumeCapture() async throws {
        resumeCallCount += 1
    }

    // MARK: - Test helpers

    /// Simulates the screen capture stopping unexpectedly.
    func simulateStop(error: Error? = nil) {
        delegate?.screenCaptureManagerDidStop(error: error)
    }
}
