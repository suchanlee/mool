import AVFoundation
import Combine
import CoreMedia
import Foundation
import ScreenCaptureKit
import SwiftUI

// MARK: - Recording Engine

/// Central coordinator for all recording subsystems.
/// Drives the recording state machine and routes buffers between managers and the writer.
@Observable
@MainActor
final class RecordingEngine {

    // MARK: - Public state
    var state: RecordingState = .idle
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var currentSession: RecordingSession?
    private(set) var lastCompletedURL: URL?

    var settings = RecordingSettings()
    let availableSources = AvailableSources()

    // MARK: - Sub-managers (internal, accessed by WindowCoordinator for preview)

    let cameraManager: any CameraManaging
    private let screenManager: any ScreenCaptureManaging
    private let audioManager: any AudioManaging
    @ObservationIgnored nonisolated(unsafe) private var videoWriter: VideoWriter?
    private unowned let storageManager: StorageManager

    // MARK: - Timers

    private var elapsedTimer: Timer?

    // MARK: - Init

    /// Production init — creates concrete managers by default.
    /// Pass non-nil values for any manager to inject a custom implementation (e.g. fakes in tests).
    init(
        storageManager: StorageManager,
        cameraManager: (any CameraManaging)? = nil,
        screenManager: (any ScreenCaptureManaging)? = nil,
        audioManager: (any AudioManaging)? = nil
    ) {
        self.storageManager = storageManager
        self.cameraManager = cameraManager ?? CameraManager()
        self.screenManager = screenManager ?? ScreenCaptureManager()
        self.audioManager = audioManager ?? AudioManager()
        self.screenManager.delegate = self
    }

    // MARK: - Public API

    func startRecording() async throws {
        guard state == .idle else { return }

        // Refresh available sources
        await availableSources.refresh()

        if settings.countdownDuration > 0 {
            await runCountdown()
        }

        try await beginCapture()
    }

    func pauseRecording() {
        guard state == .recording else { return }
        state = .paused
        elapsedTimer?.invalidate()

        let now = CMClockGetTime(CMClockGetHostTimeClock())
        videoWriter?.pause(at: now)

        Task {
            // Stop SCStream (true pause — no frames captured during pause)
            if settings.mode.includesScreen {
                try? await screenManager.pauseCapture()
            }
            // Pause camera and audio sessions
            if settings.mode.includesCamera { cameraManager.stopCapture() }
            if settings.captureMicrophone { audioManager.stopCapture() }
        }
    }

    func resumeRecording() {
        guard state == .paused else { return }
        state = .recording
        startElapsedTimer()

        Task {
            // Restart SCStream
            if settings.mode.includesScreen {
                try? await screenManager.resumeCapture()
            }
            // Restart camera and audio
            if settings.mode.includesCamera { cameraManager.startCapture() }
            if settings.captureMicrophone { audioManager.startCapture() }

            let now = CMClockGetTime(CMClockGetHostTimeClock())
            videoWriter?.resume(at: now)
        }
    }

    func stopRecording() async {
        guard state == .recording || state == .paused else { return }
        state = .finishing

        elapsedTimer?.invalidate()
        try? await screenManager.stopCapture()
        if settings.mode.includesCamera { cameraManager.stopCapture() }
        if settings.captureMicrophone { audioManager.stopCapture() }

        do {
            let url = try await videoWriter?.finish()
            lastCompletedURL = url
            currentSession?.fileURL = url
            currentSession?.duration = elapsedTime
            if let session = currentSession {
                // Persist by refreshing storage
                await storageManager.refresh()
                _ = session  // retain reference
            }
        } catch {
            print("[RecordingEngine] Writer finish failed: \(error)")
        }

        videoWriter = nil
        currentSession = nil
        state = .idle
        elapsedTime = 0
    }

    // MARK: - Private

    private func runCountdown() async {
        var remaining = settings.countdownDuration
        state = .countdown(secondsRemaining: remaining)

        while remaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            remaining -= 1
            if remaining > 0 {
                state = .countdown(secondsRemaining: remaining)
            }
        }
    }

    private func beginCapture() async throws {
        let outputURL = storageManager.newRecordingURL()
        var session = RecordingSession()
        session.fileURL = outputURL
        currentSession = session

        // Determine video size from selected source
        let size = captureSize()
        let writer = VideoWriter(
            outputURL: outputURL,
            videoSize: size,
            videoBitrate: settings.quality.videoBitrate
        )
        videoWriter = writer

        // Configure writer
        try writer.setup(
            includeCamera: settings.mode.includesCamera,
            includeMicAudio: settings.captureMicrophone,
            includeSystemAudio: settings.captureSystemAudio && settings.mode.includesScreen
        )

        // Start screen capture
        if settings.mode.includesScreen {
            // Window capture takes priority over display capture when a window is selected
            if let windowID = settings.selectedWindowID,
               let window = availableSources.windows.first(where: { $0.windowID == windowID }) {
                try await screenManager.configureForWindow(
                    window,
                    captureSystemAudio: settings.captureSystemAudio
                )
            } else {
                let displays = availableSources.displays
                if !displays.isEmpty {
                    let idx = min(settings.selectedDisplayIndex, displays.count - 1)
                    try await screenManager.configureForDisplay(
                        displays[idx],
                        excludingWindows: [],
                        captureSystemAudio: settings.captureSystemAudio
                    )
                }
            }
            try await screenManager.startCapture()
        }

        // Start camera
        if settings.mode.includesCamera {
            if !cameraManager.isRunning {
                try cameraManager.setupSession()
            }
            cameraManager.isMirrored = settings.mirrorCamera
            cameraManager.startCapture()

            // Route camera frames directly to the writer (called on capture queue)
            cameraManager.setFrameHandler { [weak self] (pixelBuffer: CVPixelBuffer, _: CMTime) in
                self?.videoWriter?.updateCameraFrame(pixelBuffer)
            }
        }

        // Start microphone
        if settings.captureMicrophone {
            try audioManager.setupSession()
            audioManager.startCapture()
            audioManager.setMicHandler { [weak self] (buffer: CMSampleBuffer) in
                self?.videoWriter?.appendMicAudio(buffer)
            }
        }

        state = .recording
        startElapsedTimer()
    }

    private func captureSize() -> CGSize {
        // Use selected display size, or fall back to 1080p
        if settings.mode.includesScreen, !availableSources.displays.isEmpty {
            let idx = min(settings.selectedDisplayIndex, availableSources.displays.count - 1)
            let d = availableSources.displays[idx]
            return CGSize(width: d.width, height: d.height)
        }
        return settings.quality.resolution
    }

    private func startElapsedTimer() {
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime += 0.5
            }
        }
    }
}

// MARK: - ScreenCaptureManagingDelegate
// These are called from capture queues (not @MainActor), so they must be nonisolated.

extension RecordingEngine: ScreenCaptureManagingDelegate {
    nonisolated func screenCaptureManagerDidOutputVideoBuffer(_ sampleBuffer: CMSampleBuffer) {
        videoWriter?.appendVideoFrame(sampleBuffer)
    }

    nonisolated func screenCaptureManagerDidOutputAudioBuffer(_ sampleBuffer: CMSampleBuffer) {
        videoWriter?.appendSystemAudio(sampleBuffer)
    }

    nonisolated func screenCaptureManagerDidStop(error: Error?) {
        if let error {
            print("[RecordingEngine] Screen capture stopped unexpectedly: \(error)")
        }
        Task { @MainActor in await self.stopRecording() }
    }
}
