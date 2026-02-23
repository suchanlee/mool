import AppKit
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
    var screenRecording: PermissionStatus = .notDetermined
    var camera: PermissionStatus = .notDetermined
    var microphone: PermissionStatus = .notDetermined
    var accessibility: PermissionStatus = .notDetermined

    var allGranted: Bool {
        screenRecording == .granted &&
            camera == .granted &&
            microphone == .granted
    }

    // MARK: - Check all permissions

    func checkAllPermissions() async {
        await checkScreenRecording()
        checkCamera()
        checkMicrophone()
        checkAccessibility()
    }

    // MARK: - Screen Recording

    func checkScreenRecording() async {
        screenRecording = CGPreflightScreenCaptureAccess() ? .granted : .denied
    }

    func requestScreenRecording() {
        let granted = CGRequestScreenCaptureAccess()
        screenRecording = granted ? .granted : .denied

        if !granted,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Camera

    func checkCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = .granted
        case .notDetermined: camera = .notDetermined
        default: camera = .denied
        }
    }

    func requestCamera() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        camera = granted ? .granted : .denied
    }

    // MARK: - Microphone

    func checkMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: microphone = .granted
        case .notDetermined: microphone = .notDetermined
        default: microphone = .denied
        }
    }

    func requestMicrophone() async {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphone = granted ? .granted : .denied
    }

    // MARK: - Accessibility (for CGEvent tap)

    func checkAccessibility() {
        // Use raw string to avoid Swift 6 concurrency warning on the global CFString var
        let options = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibility = trusted ? .granted : .denied
    }

    func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        accessibility = .notDetermined
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
