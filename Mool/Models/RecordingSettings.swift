import AppKit
import Foundation
import CoreGraphics

// MARK: - Recording Mode

enum RecordingMode: String, CaseIterable, Codable {
    case screenAndCamera = "Screen + Camera"
    case screenOnly = "Screen Only"
    case cameraOnly = "Camera Only"

    var includesScreen: Bool { self != .cameraOnly }
    var includesCamera: Bool { self != .screenOnly }
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
        case .hd720: 5_000_000    // 5 Mbps
        case .hd1080: 10_000_000  // 10 Mbps
        case .uhd4k: 40_000_000   // 40 Mbps
        }
    }
}

// MARK: - Keyboard Shortcuts

struct RecordingShortcuts: Codable {
    var startStop: RecordingShortcut = .init(key: "r", modifiers: [.command, .shift])
    var pauseResume: RecordingShortcut = .init(key: "p", modifiers: [.command, .shift])
    var toggleAnnotation: RecordingShortcut = .init(key: "a", modifiers: [.command, .shift])
    var toggleCamera: RecordingShortcut = .init(key: "c", modifiers: [.command, .shift])
    var toggleSpeakerNotes: RecordingShortcut = .init(key: "n", modifiers: [.command, .shift])
}

struct RecordingShortcut: Codable {
    var key: String
    var modifiers: NSEventModifierFlagsWrapper

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        parts.append(key.uppercased())
        return parts.joined()
    }
}

/// Codable wrapper for NSEvent.ModifierFlags
struct NSEventModifierFlagsWrapper: Codable, OptionSet {
    var rawValue: UInt

    static let command = NSEventModifierFlagsWrapper(rawValue: 1 << 0)
    static let shift   = NSEventModifierFlagsWrapper(rawValue: 1 << 1)
    static let option  = NSEventModifierFlagsWrapper(rawValue: 1 << 2)
    static let control = NSEventModifierFlagsWrapper(rawValue: 1 << 3)

    func toNSEventModifiers() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift)   { flags.insert(.shift) }
        if contains(.option)  { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        return flags
    }
}

// MARK: - Recording Settings

@Observable
final class RecordingSettings {

    // Persisted via UserDefaults
    var mode: RecordingMode = .screenAndCamera
    var quality: VideoQuality = .hd1080
    var countdownDuration: Int = 3          // seconds; 0 = no countdown
    var mirrorCamera: Bool = false
    var captureSystemAudio: Bool = true
    var captureMicrophone: Bool = true
    var shortcuts: RecordingShortcuts = .init()
    var storagePath: URL = RecordingSettings.defaultStoragePath
    var launchAtLogin: Bool = false
    var selectedCameraUniqueID: String? = nil
    var selectedMicrophoneUniqueID: String? = nil

    // Runtime-only (not persisted)
    var selectedDisplayIndex: Int = 0
    var selectedWindowID: CGWindowID? = nil

    static var defaultStoragePath: URL {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
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
            shortcuts: shortcuts,
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
        shortcuts = snapshot.shortcuts
        storagePath = snapshot.storagePath
        launchAtLogin = snapshot.launchAtLogin
        selectedCameraUniqueID = snapshot.selectedCameraUniqueID
        selectedMicrophoneUniqueID = snapshot.selectedMicrophoneUniqueID
    }

    // Codable snapshot to avoid @Observable codability issues
    private struct SettingsSnapshot: Codable {
        var mode: RecordingMode
        var quality: VideoQuality
        var countdownDuration: Int
        var mirrorCamera: Bool
        var captureSystemAudio: Bool
        var captureMicrophone: Bool
        var shortcuts: RecordingShortcuts
        var storagePath: URL
        var launchAtLogin: Bool
        var selectedCameraUniqueID: String?
        var selectedMicrophoneUniqueID: String?
    }
}
