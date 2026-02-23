import CoreMedia
import ScreenCaptureKit

// MARK: - ScreenCaptureManagingDelegate

/// Receives output from the screen capture pipeline.
/// Called on background capture queues — conforming types must be thread-safe.
protocol ScreenCaptureManagingDelegate: AnyObject {
    func screenCaptureManagerDidOutputVideoBuffer(_ sampleBuffer: CMSampleBuffer)
    func screenCaptureManagerDidOutputAudioBuffer(_ sampleBuffer: CMSampleBuffer)
    func screenCaptureManagerDidStop(error: Error?)
}

// MARK: - ScreenCaptureManaging

/// Abstracts SCStream-based screen and audio capture.
/// @MainActor-isolated to match the concrete ScreenCaptureManager class.
@MainActor
protocol ScreenCaptureManaging: AnyObject {
    var delegate: (any ScreenCaptureManagingDelegate)? { get set }

    func configureForDisplay(
        _ display: SCDisplay,
        excludingWindows: [SCWindow],
        captureSystemAudio: Bool
    ) async throws

    func configureForWindow(
        _ window: SCWindow,
        captureSystemAudio: Bool
    ) async throws

    func startCapture() async throws
    func stopCapture() async throws
    func pauseCapture() async throws
    func resumeCapture() async throws
}

// MARK: - Default argument extension

extension ScreenCaptureManaging {
    /// Convenience overload — captures a display without excluding any windows.
    func configureForDisplay(_ display: SCDisplay, captureSystemAudio: Bool) async throws {
        try await configureForDisplay(display, excludingWindows: [], captureSystemAudio: captureSystemAudio)
    }
}
