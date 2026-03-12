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

    private let stateLock = NSLock()
    private nonisolated(unsafe) var _state: WritingState = .idle
    private nonisolated(unsafe) var assetWriter: AVAssetWriter?
    private nonisolated(unsafe) var videoInput: AVAssetWriterInput?
    private nonisolated(unsafe) var audioMicInput: AVAssetWriterInput?
    private nonisolated(unsafe) var audioSysInput: AVAssetWriterInput?
    private nonisolated(unsafe) var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private nonisolated(unsafe) var sessionStarted = false
    private nonisolated(unsafe) var isPaused = false
    private nonisolated(unsafe) var pauseStartTime: CMTime = .invalid
    private nonisolated(unsafe) var totalPausedDuration: CMTime = .zero
    private nonisolated(unsafe) var latestCameraBuffer: CVPixelBuffer?
    private nonisolated(unsafe) var cameraOverlayNormalizedFrame: CGRect?
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
        try withStateLock {
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
                    AVEncoderBitRateKey: 192_000
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
                    AVEncoderBitRateKey: 192_000
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
    }

    // MARK: - Frame ingestion (called from capture queues — NOT main actor)

    func appendVideoFrame(_ sampleBuffer: CMSampleBuffer) {
        withStateLock {
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
    }

    func updateCameraFrame(_ pixelBuffer: CVPixelBuffer) {
        withStateLock {
            latestCameraBuffer = pixelBuffer
        }
    }

    func setCameraOverlayNormalizedFrame(_ normalizedFrame: CGRect?) {
        withStateLock {
            cameraOverlayNormalizedFrame = normalizedFrame
        }
    }

    /// In camera-only mode there is no SCStream video callback, so camera frames
    /// drive the writer session timeline directly.
    func appendCameraVideoFrame(_ pixelBuffer: CVPixelBuffer, at pts: CMTime) {
        withStateLock {
            guard case .writing = _state else { return }
            guard !isPaused else { return }
            guard let vInput = videoInput, let adaptor = pixelBufferAdaptor else { return }

            let adjusted = adjustedPTS(pts)
            if !sessionStarted {
                assetWriter?.startSession(atSourceTime: adjusted)
                sessionStarted = true
            }

            guard vInput.isReadyForMoreMediaData else { return }
            adaptor.append(pixelBuffer, withPresentationTime: adjusted)
        }
    }

    func appendMicAudio(_ sampleBuffer: CMSampleBuffer) {
        withStateLock {
            guard case .writing = _state, sessionStarted else { return }
            guard !isPaused, let aInput = audioMicInput, aInput.isReadyForMoreMediaData else { return }
            aInput.append(sampleBuffer)
        }
    }

    func appendSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        withStateLock {
            guard case .writing = _state, sessionStarted else { return }
            guard !isPaused, let sInput = audioSysInput, sInput.isReadyForMoreMediaData else { return }
            sInput.append(sampleBuffer)
        }
    }

    // MARK: - Pause / Resume

    func pause(at time: CMTime) {
        withStateLock {
            isPaused = true
            pauseStartTime = time
        }
    }

    func resume(at time: CMTime) {
        withStateLock {
            guard isPaused else { return }
            let delta = CMTimeSubtract(time, pauseStartTime)
            totalPausedDuration = CMTimeAdd(totalPausedDuration, delta)
            isPaused = false
        }
    }

    // MARK: - Finish (called from @MainActor)

    func finish() async throws -> URL {
        let writer = try withStateLock { () -> AVAssetWriter in
            guard case .writing = _state else { throw WriterError.notWriting }
            _state = .finishing

            videoInput?.markAsFinished()
            audioMicInput?.markAsFinished()
            audioSysInput?.markAsFinished()

            guard let writer = assetWriter else { throw WriterError.notWriting }
            return writer
        }

        await writer.finishWriting()

        if writer.status == .failed {
            let err = writer.error ?? WriterError.unknown
            withStateLock {
                _state = .failed(err)
            }
            throw err
        }

        return withStateLock {
            _state = .finished
            return outputURL
        }
    }

    func cancel() {
        withStateLock {
            assetWriter?.cancelWriting()
            videoInput = nil
            audioMicInput = nil
            audioSysInput = nil
            pixelBufferAdaptor = nil
            assetWriter = nil
            sessionStarted = false
            latestCameraBuffer = nil
            cameraOverlayNormalizedFrame = nil
            isPaused = false
            pauseStartTime = .invalid
            totalPausedDuration = .zero
            _state = .idle
        }
        try? FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Helpers

    private func adjustedPTS(_ pts: CMTime) -> CMTime {
        CMTimeSubtract(pts, totalPausedDuration)
    }

    private func withStateLock<T>(_ body: () throws -> T) rethrows -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return try body()
    }

    private func composite(screen: CVPixelBuffer, camera: CVPixelBuffer) -> CVPixelBuffer? {
        let screenCI = CIImage(cvPixelBuffer: screen)
        let cameraCI = CIImage(cvPixelBuffer: camera)
        let overlayFrame = cameraOverlayFrame(in: screenCI.extent)
        let overlaySide = min(overlayFrame.width, overlayFrame.height)

        // Fill a square PiP region first, then blend with a circular mask.
        let scale = max(
            overlayFrame.width / max(cameraCI.extent.width, 1),
            overlayFrame.height / max(cameraCI.extent.height, 1)
        )
        let fittedCamera = cameraCI.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let centeredCamera = fittedCamera.transformed(
            by: CGAffineTransform(
                translationX: (overlayFrame.width - fittedCamera.extent.width) / 2 - fittedCamera.extent.minX,
                y: (overlayFrame.height - fittedCamera.extent.height) / 2 - fittedCamera.extent.minY
            )
        )
        let squareCamera = centeredCamera
            .cropped(to: CGRect(origin: .zero, size: overlayFrame.size))
            .transformed(by: CGAffineTransform(translationX: overlayFrame.minX, y: overlayFrame.minY))

        let center = CIVector(x: overlayFrame.midX, y: overlayFrame.midY)
        let mask: CIImage? = {
            guard let radial = CIFilter(name: "CIRadialGradient") else { return nil }
            radial.setValue(center, forKey: "inputCenter")
            radial.setValue(max(overlaySide / 2 - 1, 0), forKey: "inputRadius0")
            radial.setValue(overlaySide / 2, forKey: "inputRadius1")
            radial.setValue(CIColor(red: 1, green: 1, blue: 1, alpha: 1), forKey: "inputColor0")
            radial.setValue(CIColor(red: 0, green: 0, blue: 0, alpha: 0), forKey: "inputColor1")
            return radial.outputImage?.cropped(to: screenCI.extent)
        }()

        let composited: CIImage = {
            guard let mask else { return squareCamera.composited(over: screenCI) }
            guard let blend = CIFilter(name: "CIBlendWithMask") else {
                return squareCamera.composited(over: screenCI)
            }
            blend.setValue(squareCamera, forKey: kCIInputImageKey)
            blend.setValue(screenCI, forKey: kCIInputBackgroundImageKey)
            blend.setValue(mask, forKey: kCIInputMaskImageKey)
            return blend.outputImage ?? squareCamera.composited(over: screenCI)
        }()

        guard let pool = pixelBufferAdaptor?.pixelBufferPool else { return nil }
        var out: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &out)
        guard let outputBuffer = out else { return nil }
        ciContext.render(composited, to: outputBuffer)
        return outputBuffer
    }

    private func cameraOverlayFrame(in screenExtent: CGRect) -> CGRect {
        if let normalized = cameraOverlayNormalizedFrame,
           normalized.width > 0,
           normalized.height > 0
        {
            return CGRect(
                x: screenExtent.minX + normalized.minX * screenExtent.width,
                y: screenExtent.minY + normalized.minY * screenExtent.height,
                width: normalized.width * screenExtent.width,
                height: normalized.height * screenExtent.height
            )
        }

        let margin: CGFloat = 20
        let width = screenExtent.width * 0.22
        let height = width
        return CGRect(
            x: screenExtent.maxX - width - margin,
            y: screenExtent.minY + margin,
            width: width,
            height: height
        )
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
