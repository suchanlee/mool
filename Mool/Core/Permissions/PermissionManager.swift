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
    private let screenPermissionRequestedKey = "MoolScreenPermissionRequested"

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
        if CGPreflightScreenCaptureAccess() {
            screenRecording = .granted
            return
        }

        let hasRequested = UserDefaults.standard.bool(forKey: screenPermissionRequestedKey)
        screenRecording = hasRequested ? .denied : .notDetermined
    }

    func requestScreenRecording(openSettingsOnDeny: Bool = true) {
        UserDefaults.standard.set(true, forKey: screenPermissionRequestedKey)
        let granted = CGRequestScreenCaptureAccess()
        screenRecording = granted ? .granted : .denied

        if openSettingsOnDeny, !granted,
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

    func openCameraSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
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

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
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
