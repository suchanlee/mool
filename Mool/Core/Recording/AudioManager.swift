import AVFoundation
import CoreMedia

// MARK: - Audio Manager

/// Manages microphone capture via AVCaptureSession.
/// System audio is captured directly by ScreenCaptureManager via SCStream.
@MainActor
final class AudioManager: NSObject, AudioManaging {

    private let session = AVCaptureSession()
    private var audioInput: AVCaptureDeviceInput?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var isConfigured = false
    private let outputQueue = DispatchQueue(label: "com.mool.audio.output", qos: .userInteractive)

    /// Called from capture queue — must be thread-safe.
    nonisolated(unsafe) var onMicBuffer: ((CMSampleBuffer) -> Void)?
    private(set) var isRunning: Bool = false
    private(set) var selectedMicrophoneUniqueID: String?

    // MARK: - Setup

    func setupSession() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()

        guard let mic = preferredMicrophone() ?? AVCaptureDevice.default(for: .audio) else {
            throw AudioError.noDeviceFound
        }
        selectedMicrophoneUniqueID = mic.uniqueID

        let input = try AVCaptureDeviceInput(device: mic)
        guard session.canAddInput(input) else { throw AudioError.cannotAddInput }
        session.addInput(input)
        audioInput = input

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: outputQueue)
        guard session.canAddOutput(output) else { throw AudioError.cannotAddOutput }
        session.addOutput(output)
        audioOutput = output

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

    func setMicHandler(_ handler: ((CMSampleBuffer) -> Void)?) {
        onMicBuffer = handler
    }

    // MARK: - Device switching

    func availableMicrophones() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        ).devices
    }

    func switchToMicrophone(_ device: AVCaptureDevice) throws {
        selectedMicrophoneUniqueID = device.uniqueID
        guard isConfigured else { return }

        session.beginConfiguration()
        if let existing = audioInput {
            session.removeInput(existing)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw AudioError.cannotAddInput }
        session.addInput(input)
        audioInput = input
        session.commitConfiguration()
    }

    private func preferredMicrophone() -> AVCaptureDevice? {
        guard let selectedMicrophoneUniqueID else { return nil }
        return availableMicrophones().first(where: { $0.uniqueID == selectedMicrophoneUniqueID })
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
