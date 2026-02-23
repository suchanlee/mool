import AVFoundation
import Combine
import CoreGraphics
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
    private var runtimeErrorMessage: String?

    var settings = RecordingSettings()
    let availableSources = AvailableSources()

    // MARK: - Sub-managers (internal, accessed by WindowCoordinator for preview)

    let cameraManager: any CameraManaging
    private let screenManager: any ScreenCaptureManaging
    private let audioManager: any AudioManaging
    @ObservationIgnored private nonisolated(unsafe) var videoWriter: VideoWriter?
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
        runtimeErrorMessage = nil

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
                _ = session // retain reference
            }
        } catch {
            print("[RecordingEngine] Writer finish failed: \(error)")
        }

        cameraManager.setFrameHandler(nil)
        audioManager.setMicHandler(nil)
        videoWriter = nil
        currentSession = nil
        state = .idle
        elapsedTime = 0
    }

    func consumeRuntimeErrorMessage() -> String? {
        defer { runtimeErrorMessage = nil }
        return runtimeErrorMessage
    }

    func prepareQuickRecorderContext() async {
        guard state == .idle else { return }
        await availableSources.refresh()
        syncCameraPreviewForCurrentSettings()
    }

    func teardownQuickRecorderContext() {
        guard state == .idle else { return }
        cameraManager.setFrameHandler(nil)
        cameraManager.stopCapture()
    }

    func availableCameraDevices() -> [AVCaptureDevice] {
        cameraManager.availableCameras()
    }

    func availableMicrophoneDevices() -> [AVCaptureDevice] {
        audioManager.availableMicrophones()
    }

    func setCameraEnabled(_ enabled: Bool) {
        if enabled {
            if settings.mode == .screenOnly {
                settings.mode = .screenAndCamera
            }
        } else {
            if settings.mode == .screenAndCamera || settings.mode == .cameraOnly {
                settings.mode = .screenOnly
            }
        }
        settings.save()
        syncCameraPreviewForCurrentSettings()
    }

    func selectCameraDevice(uniqueID: String?) {
        settings.selectedCameraUniqueID = uniqueID
        settings.save()

        let device: AVCaptureDevice? = if let uniqueID {
            cameraManager.availableCameras().first(where: { $0.uniqueID == uniqueID })
        } else {
            defaultCameraDevice()
        }

        guard let device else {
            runtimeErrorMessage = "Selected camera is no longer available."
            return
        }

        do {
            try cameraManager.switchToCamera(device)
        } catch {
            runtimeErrorMessage = "Failed to switch camera: \(error.localizedDescription)"
        }
    }

    func selectMicrophoneDevice(uniqueID: String?) {
        settings.selectedMicrophoneUniqueID = uniqueID
        settings.save()

        let device: AVCaptureDevice? = if let uniqueID {
            audioManager.availableMicrophones().first(where: { $0.uniqueID == uniqueID })
        } else {
            defaultMicrophoneDevice()
        }

        guard let device else {
            runtimeErrorMessage = "Selected microphone is no longer available."
            return
        }

        do {
            try audioManager.switchToMicrophone(device)
        } catch {
            runtimeErrorMessage = "Failed to switch microphone: \(error.localizedDescription)"
        }
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
        if settings.mode.includesScreen {
            guard CGPreflightScreenCaptureAccess() else {
                throw ScreenCaptureError.permissionDenied
            }

            let hasSelectedWindow = settings.selectedWindowID != nil &&
                availableSources.windows.contains(where: { $0.windowID == settings.selectedWindowID })
            let hasDisplay = !availableSources.displays.isEmpty
            guard hasSelectedWindow || hasDisplay else {
                throw RecordingEngineError.noAvailableScreenSource
            }
        }

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
               let window = availableSources.windows.first(where: { $0.windowID == windowID })
            {
                try await screenManager.configureForWindow(
                    window,
                    captureSystemAudio: settings.captureSystemAudio
                )
            } else {
                let displays = availableSources.displays
                let idx = min(settings.selectedDisplayIndex, displays.count - 1)
                try await screenManager.configureForDisplay(
                    displays[idx],
                    excludingWindows: [],
                    captureSystemAudio: settings.captureSystemAudio
                )
            }
            try await screenManager.startCapture()
        }

        // Start camera
        if settings.mode.includesCamera {
            if !cameraManager.isRunning {
                try cameraManager.setupSession()
            }
            if let uniqueID = settings.selectedCameraUniqueID,
               let device = cameraManager.availableCameras().first(where: { $0.uniqueID == uniqueID })
            {
                try? cameraManager.switchToCamera(device)
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
            if let uniqueID = settings.selectedMicrophoneUniqueID,
               let device = audioManager.availableMicrophones().first(where: { $0.uniqueID == uniqueID })
            {
                try? audioManager.switchToMicrophone(device)
            }
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

    private func syncCameraPreviewForCurrentSettings() {
        guard state == .idle else { return }

        if settings.mode.includesCamera {
            do {
                try cameraManager.setupSession()
                if let uniqueID = settings.selectedCameraUniqueID,
                   let device = cameraManager.availableCameras().first(where: { $0.uniqueID == uniqueID })
                {
                    try cameraManager.switchToCamera(device)
                }
                cameraManager.isMirrored = settings.mirrorCamera
                cameraManager.setFrameHandler(nil)
                cameraManager.startCapture()
            } catch {
                runtimeErrorMessage = "Camera preview unavailable: \(error.localizedDescription)"
            }
        } else {
            cameraManager.setFrameHandler(nil)
            cameraManager.stopCapture()
        }
    }

    private func defaultCameraDevice() -> AVCaptureDevice? {
        let cameras = cameraManager.availableCameras()
        return cameras.first(where: { $0.position == .front }) ??
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) ??
            AVCaptureDevice.default(for: .video) ??
            cameras.first
    }

    private func defaultMicrophoneDevice() -> AVCaptureDevice? {
        let microphones = audioManager.availableMicrophones()
        return AVCaptureDevice.default(for: .audio) ?? microphones.first
    }
}

enum RecordingEngineError: LocalizedError {
    case noAvailableScreenSource

    var errorDescription: String? {
        switch self {
        case .noAvailableScreenSource:
            "No display or window source is currently available."
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
        Task { @MainActor in
            if let error {
                print("[RecordingEngine] Screen capture stopped unexpectedly: \(error)")
            }
            if self.state == .recording || self.state == .paused {
                self.runtimeErrorMessage = "Recording stopped because the selected screen source is no longer available."
            }
            await self.stopRecording()
        }
    }
}
