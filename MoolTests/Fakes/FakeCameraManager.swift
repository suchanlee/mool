import AVFoundation
import CoreMedia
import CoreVideo
@testable import Mool

// MARK: - FakeCameraManager

/// Test double for CameraManaging.
/// Provides an inactive preview layer and records method calls.
@MainActor
final class FakeCameraManager: CameraManaging {

    /// A real but inactive layer — satisfies the protocol without starting a session.
    let previewLayer = AVCaptureVideoPreviewLayer()

    var isMirrored: Bool = false
    private(set) var isRunning: Bool = false
    private(set) var selectedCameraUniqueID: String?

    // MARK: - Recorded state

    var setupCallCount = 0
    var startCallCount = 0
    var stopCallCount = 0
    var switchCallCount = 0
    var capturedFrameHandler: ((CVPixelBuffer, CMTime) -> Void)?

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

    func availableCameras() -> [AVCaptureDevice] {
        []
    }

    func switchToCamera(_ device: AVCaptureDevice) throws {
        switchCallCount += 1
        selectedCameraUniqueID = device.uniqueID
    }

    func setFrameHandler(_ handler: ((CVPixelBuffer, CMTime) -> Void)?) {
        capturedFrameHandler = handler
    }
}
