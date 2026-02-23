import AVFoundation
import CoreMedia
import CoreVideo

// MARK: - CameraManaging

/// Abstracts AVCaptureSession-based camera capture and preview.
/// @MainActor-isolated to match the concrete CameraManager class.
@MainActor
protocol CameraManaging: AnyObject {
    /// Live preview layer — read by WindowCoordinator to display the camera bubble.
    var previewLayer: AVCaptureVideoPreviewLayer { get }

    var isMirrored: Bool { get set }
    var isRunning: Bool { get }

    func setupSession() throws
    func startCapture()
    func stopCapture()

    /// Registers a closure to receive each camera frame (called on the capture queue).
    /// Pass nil to clear the handler.
    func setFrameHandler(_ handler: ((CVPixelBuffer, CMTime) -> Void)?)
}
