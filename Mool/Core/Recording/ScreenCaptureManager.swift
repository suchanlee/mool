import ScreenCaptureKit
import CoreMedia
import CoreVideo
import Foundation

// MARK: - Screen Capture Manager

@MainActor
final class ScreenCaptureManager: NSObject, ScreenCaptureManaging {

    nonisolated(unsafe) weak var delegate: (any ScreenCaptureManagingDelegate)?

    private var stream: SCStream?
    private var savedFilter: SCContentFilter?
    private var captureAudio: Bool = false

    private let videoOutputQueue = DispatchQueue(label: "com.mool.screencapture.video", qos: .userInteractive)
    private let audioOutputQueue = DispatchQueue(label: "com.mool.screencapture.audio", qos: .userInteractive)

    // MARK: - Configuration

    func configureForDisplay(_ display: SCDisplay, excludingWindows: [SCWindow] = [], captureSystemAudio: Bool) async throws {
        let filter = SCContentFilter(display: display, excludingWindows: excludingWindows)
        savedFilter = filter
        captureAudio = captureSystemAudio
        try await setupStream(filter: filter)
    }

    func configureForWindow(_ window: SCWindow, captureSystemAudio: Bool) async throws {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        savedFilter = filter
        captureAudio = captureSystemAudio
        try await setupStream(filter: filter)
    }

    private func setupStream(filter: SCContentFilter) async throws {
        let config = SCStreamConfiguration()
        config.width = Int(filter.contentRect.width) * 2   // @2x for Retina
        config.height = Int(filter.contentRect.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        config.scalesToFit = false

        if captureAudio {
            config.capturesAudio = true
            config.sampleRate = 48000
            config.channelCount = 2
        }

        let newStream = SCStream(filter: filter, configuration: config, delegate: self)
        self.stream = newStream

        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoOutputQueue)
        if captureAudio {
            try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioOutputQueue)
        }
    }

    // MARK: - Control

    func startCapture() async throws {
        guard let stream else { throw ScreenCaptureError.notConfigured }
        try await stream.startCapture()
    }

    func stopCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        self.stream = nil
    }

    /// True pause: stops the SCStream. Call resumeCapture() to restart with same filter.
    func pauseCapture() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        self.stream = nil
    }

    /// Restarts the SCStream from the saved filter after a pause.
    func resumeCapture() async throws {
        guard let filter = savedFilter else { throw ScreenCaptureError.notConfigured }
        try await setupStream(filter: filter)
        try await startCapture()
    }
}

// MARK: - SCStreamOutput

extension ScreenCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }
        // Call delegate directly on the capture queue — delegate must be thread-safe
        switch type {
        case .screen:
            delegate?.screenCaptureManagerDidOutputVideoBuffer(sampleBuffer)
        case .audio:
            delegate?.screenCaptureManagerDidOutputAudioBuffer(sampleBuffer)
        default:
            break
        }
    }
}

// MARK: - SCStreamDelegate

extension ScreenCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            self.delegate?.screenCaptureManagerDidStop(error: error)
        }
    }
}

// MARK: - Errors

enum ScreenCaptureError: LocalizedError {
    case notConfigured
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured: "Screen capture stream not configured."
        case .permissionDenied: "Screen recording permission is required."
        }
    }
}
