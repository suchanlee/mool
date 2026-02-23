import AppKit
import Foundation

// MARK: - Saved Recording

struct SavedRecording: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let title: String
    let createdAt: Date
    let duration: TimeInterval?
    let fileSize: Int64

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDuration: String? {
        guard let d = duration else { return nil }
        let m = Int(d) / 60
        let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Storage Manager

@Observable
@MainActor
final class StorageManager {

    var recordings: [SavedRecording] = []
    var totalSize: Int64 = 0
    var storagePath: URL

    init() {
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
        storagePath = movies.appendingPathComponent("Mool", isDirectory: true)
        ensureDirectoryExists()
        Task { await refresh() }
    }

    // MARK: - Directory Management

    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: storagePath, withIntermediateDirectories: true)
    }

    func setStoragePath(_ url: URL) {
        storagePath = url
        ensureDirectoryExists()
        Task { await refresh() }
    }

    // MARK: - Enumeration

    func refresh() async {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: storagePath,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var result: [SavedRecording] = []
        var total: Int64 = 0

        for url in contents where url.pathExtension == "mov" || url.pathExtension == "mp4" {
            let attrs = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let created = attrs?.creationDate ?? Date.distantPast
            let size = Int64(attrs?.fileSize ?? 0)
            total += size

            let recording = SavedRecording(
                id: UUID(),
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                createdAt: created,
                duration: nil,  // TODO: read from AVAsset if needed
                fileSize: size
            )
            result.append(recording)
        }

        recordings = result.sorted { $0.createdAt > $1.createdAt }
        totalSize = total
    }

    // MARK: - Actions

    func delete(_ recording: SavedRecording) throws {
        try FileManager.default.trashItem(at: recording.url, resultingItemURL: nil)
        recordings.removeAll { $0.id == recording.id }
        totalSize -= recording.fileSize
    }

    func rename(_ recording: SavedRecording, to newTitle: String) async throws {
        let newURL = recording.url
            .deletingLastPathComponent()
            .appendingPathComponent(newTitle)
            .appendingPathExtension(recording.url.pathExtension)
        try FileManager.default.moveItem(at: recording.url, to: newURL)
        await refresh()
    }

    func revealInFinder(_ recording: SavedRecording) {
        NSWorkspace.shared.activateFileViewerSelecting([recording.url])
    }

    func copyPath(_ recording: SavedRecording) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(recording.url.path, forType: .string)
    }

    // MARK: - URL Generation

    func newRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let name = "Mool_\(formatter.string(from: .now)).mov"
        return storagePath.appendingPathComponent(name)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}
