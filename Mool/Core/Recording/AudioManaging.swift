import CoreMedia

// MARK: - AudioManaging

/// Abstracts AVCaptureSession-based microphone capture.
/// @MainActor-isolated to match the concrete AudioManager class.
@MainActor
protocol AudioManaging: AnyObject {
    var isRunning: Bool { get }

    func setupSession() throws
    func startCapture()
    func stopCapture()

    /// Registers a closure to receive each microphone sample buffer (called on the capture queue).
    /// Pass nil to clear the handler.
    func setMicHandler(_ handler: ((CMSampleBuffer) -> Void)?)
}
