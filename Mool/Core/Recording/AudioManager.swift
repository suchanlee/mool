import AVFoundation
import CoreMedia

// MARK: - Audio Manager

/// Manages microphone capture via AVCaptureSession.
/// System audio is captured directly by ScreenCaptureManager via SCStream.
@MainActor
final class AudioManager: NSObject {

    private let session = AVCaptureSession()
    private var audioOutput: AVCaptureAudioDataOutput?
    private let outputQueue = DispatchQueue(label: "com.mool.audio.output", qos: .userInteractive)

    /// Called from capture queue — must be thread-safe.
    nonisolated(unsafe) var onMicBuffer: ((CMSampleBuffer) -> Void)?
    private(set) var isRunning: Bool = false

    // MARK: - Setup

    func setupSession() throws {
        session.beginConfiguration()

        guard let mic = AVCaptureDevice.default(for: .audio) else {
            throw AudioError.noDeviceFound
        }

        let input = try AVCaptureDeviceInput(device: mic)
        guard session.canAddInput(input) else { throw AudioError.cannotAddInput }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else { throw AudioError.cannotAddOutput }
        session.addOutput(output)
        audioOutput = output

        session.commitConfiguration()
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
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension AudioManager: AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Call directly on capture queue — receiver must handle thread safety
        onMicBuffer?(sampleBuffer)
    }
}

// MARK: - Errors

enum AudioError: LocalizedError {
    case noDeviceFound
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .noDeviceFound: "No microphone found."
        case .cannotAddInput: "Cannot add microphone input."
        case .cannotAddOutput: "Cannot add audio output."
        }
    }
}
