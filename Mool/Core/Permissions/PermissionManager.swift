import AppKit
import AVFAudio
import AVFoundation
import CoreGraphics
import ScreenCaptureKit

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case granted
    case denied
}

// MARK: - Permission Manager

@Observable
@MainActor
final class PermissionManager {
    private enum PermissionOverride: String {
        case granted
        case denied
        case notDetermined

        var status: PermissionStatus {
            switch self {
            case .granted: .granted
            case .denied: .denied
            case .notDetermined: .notDetermined
            }
        }
    }

    private let env = ProcessInfo.processInfo.environment
    private let permissionTracePath: String?
    private let disableSettingsOpen: Bool
    private let screenPermissionOverride: PermissionOverride?
    private let cameraPermissionOverride: PermissionOverride?
    private let microphonePermissionOverride: PermissionOverride?

    var screenRecording: PermissionStatus = .notDetermined
    var camera: PermissionStatus = .notDetermined
    var microphone: PermissionStatus = .notDetermined
    var accessibility: PermissionStatus = .notDetermined

    init() {
        permissionTracePath = env["MOOL_PERMISSION_TRACE_PATH"]
        disableSettingsOpen = env["MOOL_TEST_DISABLE_SYSTEM_SETTINGS_OPEN"] == "1"
        if let rawValue = env["MOOL_TEST_SCREEN_PERMISSION"] {
            screenPermissionOverride = PermissionOverride(rawValue: rawValue)
        } else {
            screenPermissionOverride = nil
        }
        if let rawValue = env["MOOL_TEST_CAMERA_PERMISSION"] {
            cameraPermissionOverride = PermissionOverride(rawValue: rawValue)
        } else {
            cameraPermissionOverride = nil
        }
        if let rawValue = env["MOOL_TEST_MIC_PERMISSION"] {
            microphonePermissionOverride = PermissionOverride(rawValue: rawValue)
        } else {
            microphonePermissionOverride = nil
        }
    }

    var allGranted: Bool {
        screenRecording == .granted &&
            camera == .granted &&
            microphone == .granted
    }

    // MARK: - Refresh (no system prompts)

    func refresh() async {
        if let screenPermissionOverride {
            screenRecording = screenPermissionOverride.status
            tracePermission("refreshScreenRecording override=\(screenPermissionOverride.rawValue)")
        } else {
            screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
            tracePermission("refreshScreenRecording preflight=\(statusDescription(screenRecording))")
        }
        refreshCamera()
        refreshMicrophone()
        refreshAccessibility()
    }

    private func refreshCamera() {
        if let cameraPermissionOverride {
            camera = cameraPermissionOverride.status
            tracePermission("refreshCamera override=\(cameraPermissionOverride.rawValue)")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = .granted
        case .notDetermined: camera = .notDetermined
        default: camera = .denied
        }
        tracePermission("refreshCamera status=\(statusDescription(camera))")
    }

    private func refreshMicrophone() {
        if let microphonePermissionOverride {
            microphone = microphonePermissionOverride.status
            tracePermission("refreshMicrophone override=\(microphonePermissionOverride.rawValue)")
            return
        }

        microphone = microphonePermissionStatus(from: AVAudioApplication.shared.recordPermission)
        tracePermission("refreshMicrophone status=\(statusDescription(microphone))")
    }

    private func refreshAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        accessibility = AXIsProcessTrustedWithOptions(options) ? .granted : .denied
    }

    // MARK: - Request methods (may show system prompt)

    /// Triggers SCShareableContent which registers the app in TCC on macOS 15.
    /// Returns true if granted, false if denied.
    @discardableResult
    func requestScreenRecording() async -> Bool {
        if let screenPermissionOverride {
            screenRecording = screenPermissionOverride.status
            tracePermission("requestScreenRecording override=\(screenPermissionOverride.rawValue)")
            return screenRecording == .granted
        }

        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            screenRecording = .granted
            tracePermission("requestScreenRecording result=granted")
            return true
        } catch {
            screenRecording = .denied
            tracePermission("requestScreenRecording result=denied")
            return false
        }
    }

    /// Returns true immediately if already authorized; shows system prompt if notDetermined.
    /// Returns false (without prompting) if already denied.
    @discardableResult
    func requestCamera() async -> Bool {
        if let cameraPermissionOverride {
            camera = cameraPermissionOverride.status
            tracePermission("requestCamera override=\(cameraPermissionOverride.rawValue)")
            return camera == .granted
        }

        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted ? .granted : .denied
        tracePermission("requestCamera result=\(statusDescription(camera))")
        return granted
    }

    /// Returns true immediately if already authorized; shows system prompt if notDetermined.
    /// Returns false (without prompting) if already denied.
    @discardableResult
    func requestMicrophone() async -> Bool {
        if let microphonePermissionOverride {
            microphone = microphonePermissionOverride.status
            tracePermission("requestMicrophone override=\(microphonePermissionOverride.rawValue)")
            return microphone == .granted
        }

        let granted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        microphone = microphonePermissionStatus(from: AVAudioApplication.shared.recordPermission)
        if microphone == .notDetermined {
            microphone = granted ? .granted : .denied
        }
        tracePermission("requestMicrophone result=\(statusDescription(microphone))")
        return granted
    }

    // MARK: - Open Settings

    func openScreenRecordingSettings() {
        tracePermission("openScreenRecordingSettings")
        if disableSettingsOpen { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCameraSettings() {
        tracePermission("openCameraSettings")
        if disableSettingsOpen { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophoneSettings() {
        tracePermission("openMicrophoneSettings")
        if disableSettingsOpen { return }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Accessibility

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        accessibility = .notDetermined
    }

    private func statusDescription(_ status: PermissionStatus) -> String {
        switch status {
        case .notDetermined: "notDetermined"
        case .granted: "granted"
        case .denied: "denied"
        }
    }

    private func microphonePermissionStatus(from recordPermission: AVAudioApplication.recordPermission) -> PermissionStatus {
        switch recordPermission {
        case .granted:
            .granted
        case .undetermined:
            .notDetermined
        case .denied:
            .denied
        @unknown default:
            .denied
        }
    }

    private func tracePermission(_ message: String) {
        guard let permissionTracePath, !permissionTracePath.isEmpty else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let url = URL(fileURLWithPath: permissionTracePath)
        guard let data = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: permissionTracePath),
           let handle = try? FileHandle(forWritingTo: url)
        {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
                return
            } catch {
                try? data.write(to: url, options: .atomic)
                return
            }
        }

        try? data.write(to: url, options: .atomic)
    }
}
