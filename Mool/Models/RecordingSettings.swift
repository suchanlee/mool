import CoreGraphics
import Foundation

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Codable {
    case screenAndCamera = "Screen + Camera"
    case screenOnly = "Screen Only"
    case cameraOnly = "Camera Only"

    var includesScreen: Bool {
        self != .cameraOnly
    }

    var includesCamera: Bool {
        self != .screenOnly
    }
}

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable, Codable {
    case hd720 = "720p HD"
    case hd1080 = "1080p Full HD"
    case uhd4k = "4K UHD"

    var resolution: CGSize {
        switch self {
        case .hd720: CGSize(width: 1280, height: 720)
        case .hd1080: CGSize(width: 1920, height: 1080)
        case .uhd4k: CGSize(width: 3840, height: 2160)
        }
    }

    var videoBitrate: Int {
        switch self {
        case .hd720: 5_000_000 // 5 Mbps
        case .hd1080: 10_000_000 // 10 Mbps
        case .uhd4k: 40_000_000 // 40 Mbps
        }
    }
}

// MARK: - Recording Settings

@Observable
final class RecordingSettings {
    // Persisted via UserDefaults
    var mode: RecordingMode = .screenAndCamera
    var quality: VideoQuality = .hd1080
    var countdownDuration: Int = 3 // seconds; 0 = no countdown
    var mirrorCamera: Bool = false
    var captureSystemAudio: Bool = true
    var captureMicrophone: Bool = true
    var storagePath: URL = RecordingSettings.defaultStoragePath
    var launchAtLogin: Bool = false
    var selectedCameraUniqueID: String?
    var selectedMicrophoneUniqueID: String?

    // Runtime-only (not persisted)
    var selectedDisplayIndex: Int = 0
    var selectedWindowID: CGWindowID?

    static var defaultStoragePath: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Movies", isDirectory: true)
        return movies.appendingPathComponent("Mool", isDirectory: true)
    }

    private static let defaultsKey = "MoolRecordingSettings"

    init() {
        load()
    }

    func save() {
        let encoder = JSONEncoder()
        let snapshot = SettingsSnapshot(
            mode: mode,
            quality: quality,
            countdownDuration: countdownDuration,
            mirrorCamera: mirrorCamera,
            captureSystemAudio: captureSystemAudio,
            captureMicrophone: captureMicrophone,
            storagePath: storagePath,
            launchAtLogin: launchAtLogin,
            selectedCameraUniqueID: selectedCameraUniqueID,
            selectedMicrophoneUniqueID: selectedMicrophoneUniqueID
        )
        if let data = try? encoder.encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
              let snapshot = try? JSONDecoder().decode(SettingsSnapshot.self, from: data)
        else { return }
        mode = snapshot.mode
        quality = snapshot.quality
        countdownDuration = snapshot.countdownDuration
        mirrorCamera = snapshot.mirrorCamera
        captureSystemAudio = snapshot.captureSystemAudio
        captureMicrophone = snapshot.captureMicrophone
        storagePath = snapshot.storagePath
        launchAtLogin = snapshot.launchAtLogin
        selectedCameraUniqueID = snapshot.selectedCameraUniqueID
        selectedMicrophoneUniqueID = snapshot.selectedMicrophoneUniqueID
    }

    /// Codable snapshot to avoid @Observable codability issues
    private struct SettingsSnapshot: Codable {
        var mode: RecordingMode
        var quality: VideoQuality
        var countdownDuration: Int
        var mirrorCamera: Bool
        var captureSystemAudio: Bool
        var captureMicrophone: Bool
        var storagePath: URL
        var launchAtLogin: Bool
        var selectedCameraUniqueID: String?
        var selectedMicrophoneUniqueID: String?
    }
}
