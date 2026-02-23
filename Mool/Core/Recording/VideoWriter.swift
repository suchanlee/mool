import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import Foundation

// MARK: - Video Writer

/// Composites screen frames with an optional camera PiP and writes to a .mov file.
/// Intentionally NOT @MainActor — it is called directly from capture queues
/// (AVAssetWriter is designed for real-time, any-thread use).
final class VideoWriter: Sendable {

    // MARK: - State (accessed only from internal serial queue)

    enum WritingState { case idle, writing, finishing, finished, failed(any Error) }

    private let stateQueue = DispatchQueue(label: "com.mool.writer.state")
    nonisolated(unsafe) private var _state: WritingState = .idle
    nonisolated(unsafe) private var assetWriter: AVAssetWriter?
    nonisolated(unsafe) private var videoInput: AVAssetWriterInput?
    nonisolated(unsafe) private var audioMicInput: AVAssetWriterInput?
    nonisolated(unsafe) private var audioSysInput: AVAssetWriterInput?
    nonisolated(unsafe) private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    nonisolated(unsafe) private var sessionStarted = false
    nonisolated(unsafe) private var isPaused = false
    nonisolated(unsafe) private var pauseStartTime: CMTime = .invalid
    nonisolated(unsafe) private var totalPausedDuration: CMTime = .zero
    nonisolated(unsafe) private var latestCameraBuffer: CVPixelBuffer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    private let outputURL: URL
    private let videoSize: CGSize
    private let videoBitrate: Int

    // MARK: - Init

    init(outputURL: URL, videoSize: CGSize, videoBitrate: Int) {
        self.outputURL = outputURL
        self.videoSize = videoSize
        self.videoBitrate = videoBitrate
    }

    // MARK: - Setup (called from @MainActor before capture starts)

    func setup(includeCamera: Bool, includeMicAudio: Bool, includeSystemAudio: Bool) throws {
        try? FileManager.default.removeItem(at: outputURL)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(videoSize.width),
            AVVideoHeightKey: Int(videoSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: 60
            ]
        ]
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        writer.add(vInput)
        videoInput = vInput

        let bufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(videoSize.width),
            kCVPixelBufferHeightKey as String: Int(videoSize.height),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: vInput,
            sourcePixelBufferAttributes: bufferAttrs
        )

        if includeMicAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192000
            ]
            let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            aInput.expectsMediaDataInRealTime = true
            writer.add(aInput)
            audioMicInput = aInput
        }

        if includeSystemAudio {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 192000
            ]
            let sInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            sInput.expectsMediaDataInRealTime = true
            writer.add(sInput)
            audioSysInput = sInput
        }

        writer.startWriting()
        assetWriter = writer
        _state = .writing
    }

    // MARK: - Frame ingestion (called from capture queues — NOT main actor)

    func appendVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        guard case .writing = _state else { return }
        guard !isPaused else { return }
        guard let vInput = videoInput, let adaptor = pixelBufferAdaptor else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let pts = adjustedPTS(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))

        if !sessionStarted {
            assetWriter?.startSession(atSourceTime: pts)
            sessionStarted = true
        }

        guard vInput.isReadyForMoreMediaData else { return }

        if let cameraBuffer = latestCameraBuffer {
            let composited = composite(screen: imageBuffer, camera: cameraBuffer)
            adaptor.append(composited ?? imageBuffer, withPresentationTime: pts)
        } else {
            adaptor.append(imageBuffer, withPresentationTime: pts)
        }
    }

    func updateCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        latestCameraBuffer = pixelBuffer
    }

    func appendMicAudio(_ sampleBuffer: CMSampleBuffer) {
        guard case .writing = _state, sessionStarted else { return }
        guard !isPaused, let aInput = audioMicInput, aInput.isReadyForMoreMediaData else { return }
        aInput.append(sampleBuffer)
    }

    func appendSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard case .writing = _state, sessionStarted else { return }
        guard !isPaused, let sInput = audioSysInput, sInput.isReadyForMoreMediaData else { return }
        sInput.append(sampleBuffer)
    }

    // MARK: - Pause / Resume

    func pause(at time: CMTime) {
        isPaused = true
        pauseStartTime = time
    }

    func resume(at time: CMTime) {
        guard isPaused else { return }
        let delta = CMTimeSubtract(time, pauseStartTime)
        totalPausedDuration = CMTimeAdd(totalPausedDuration, delta)
        isPaused = false
    }

    // MARK: - Finish (called from @MainActor)

    func finish() async throws -> URL {
        guard case .writing = _state else { throw WriterError.notWriting }
        _state = .finishing

        videoInput?.markAsFinished()
        audioMicInput?.markAsFinished()
        audioSysInput?.markAsFinished()

        guard let writer = assetWriter else { throw WriterError.notWriting }
        await writer.finishWriting()

        if writer.status == .failed {
            let err = writer.error ?? WriterError.unknown
            _state = .failed(err)
            throw err
        }

        _state = .finished
        return outputURL
    }

    // MARK: - Helpers

    private func adjustedPTS(_ pts: CMTime) -> CMTime {
        CMTimeSubtract(pts, totalPausedDuration)
    }

    private func composite(screen: CVPixelBuffer, camera: CVPixelBuffer) -> CVPixelBuffer? {
        let screenCI = CIImage(cvPixelBuffer: screen)
        let cameraCI = CIImage(cvPixelBuffer: camera)
        let screenW = CGFloat(CVPixelBufferGetWidth(screen))
        let pipW = screenW * 0.22
        let camAspect = CGFloat(CVPixelBufferGetWidth(camera)) / CGFloat(CVPixelBufferGetHeight(camera))
        let pipH = pipW / camAspect
        let margin: CGFloat = 20
        let pipX = screenW - pipW - margin
        let pipY = margin

        let scaledCamera = cameraCI
            .transformed(by: CGAffineTransform(
                scaleX: pipW / max(cameraCI.extent.width, 1),
                y: pipH / max(cameraCI.extent.height, 1)
            ))
            .transformed(by: CGAffineTransform(translationX: pipX, y: pipY))

        let composited = scaledCamera.composited(over: screenCI)

        guard let pool = pixelBufferAdaptor?.pixelBufferPool else { return nil }
        var out: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        guard let outputBuffer = out else { return nil }
        ciContext.render(composited, to: outputBuffer)
        return outputBuffer
    }
}

// MARK: - Errors

enum WriterError: LocalizedError {
    case notWriting
    case unknown

    var errorDescription: String? {
        switch self {
        case .notWriting: "Writer is not in writing state."
        case .unknown: "An unknown error occurred during writing."
        }
    }
}
