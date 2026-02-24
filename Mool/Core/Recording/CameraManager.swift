import AppKit
import AVFoundation
import CoreVideo

// MARK: - Camera Manager

@MainActor
final class CameraManager: NSObject, CameraManaging {
    /// Live preview layer for display in the camera bubble
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let session = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private let outputQueue = DispatchQueue(label: "com.mool.camera.output", qos: .userInteractive)

    /// Called from the capture queue — must be thread-safe.
    nonisolated(unsafe) var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    /// Mirror is applied to both preview and video output connection.
    var isMirrored: Bool = false {
        didSet { applyMirrorConfiguration() }
    }

    private(set) var isRunning: Bool = false
    private(set) var selectedCameraUniqueID: String?

    // MARK: - Setup

    func setupSession() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = preferredCameraDevice() ??
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
            AVCaptureDevice.default(for: .video)
        else { throw CameraError.noDeviceFound }
        selectedCameraUniqueID = device.uniqueID

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.cannotAddInput }
        session.addInput(input)
        videoInput = input

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: outputQueue)

        guard session.canAddOutput(output) else { throw CameraError.cannotAddOutput }
        session.addOutput(output)
        videoOutput = output

        // Configure connection
        if let connection = output.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }

        // Hook up preview layer
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        applyMirrorConfiguration()

        session.commitConfiguration()
        isConfigured = true
    }

    // MARK: - Control

    func startCapture() {
        guard !session.isRunning else { return }
        session.startRunning()
        isRunning = true
    }

    func stopCapture() {
        guard session.isRunning else { return }
        session.stopRunning()
        isRunning = false
    }

    func setFrameHandler(_ handler: ((CVPixelBuffer, CMTime) -> Void)?) {
        onFrame = handler
    }

    // MARK: - Device switching

    func availableCameras() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    func switchToCamera(_ device: AVCaptureDevice) throws {
        selectedCameraUniqueID = device.uniqueID
        guard isConfigured else { return }

        session.beginConfiguration()
        if let existing = videoInput {
            session.removeInput(existing)
        }
        let newInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(newInput) else { throw CameraError.cannotAddInput }
        session.addInput(newInput)
        videoInput = newInput
        session.commitConfiguration()
        applyMirrorConfiguration()
    }

    // MARK: - Private

    private func applyMirrorConfiguration() {
        // Mirror the preview by flipping the CALayer transform
        previewLayer.transform = isMirrored
            ? CATransform3DMakeScale(-1, 1, 1)
            : CATransform3DIdentity

        if let connection = videoOutput?.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }

    private func preferredCameraDevice() -> AVCaptureDevice? {
        guard let selectedCameraUniqueID else { return nil }
        return availableCameras().first(where: { $0.uniqueID == selectedCameraUniqueID })
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        // Call directly on capture queue — VideoWriter handles thread safety
        onFrame?(pixelBuffer, pts)
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case noDeviceFound
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noDeviceFound: "No camera device found."
        case .cannotAddInput: "Cannot add camera input to capture session."
        case .cannotAddOutput: "Cannot add camera output to capture session."
        }
    }
}
