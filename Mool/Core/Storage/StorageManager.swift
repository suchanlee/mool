import AppKit
import AVFoundation
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

    enum TrimError: LocalizedError {
        case exporterUnavailable
        case unsupportedFileType
        case invalidRange
        case exportFailed(String)
        case missingOutputURL

        var errorDescription: String? {
            switch self {
            case .exporterUnavailable:
                "Unable to create a trim export session."
            case .unsupportedFileType:
                "This recording format is not supported for trimming."
            case .invalidRange:
                "The selected trim range is invalid."
            case let .exportFailed(message):
                "Trim failed: \(message)"
            case .missingOutputURL:
                "Trim failed because the output file could not be created."
            }
        }
    }

    init() {
        let defaultMovies = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Movies", isDirectory: true)
        let movies = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? defaultMovies
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
            let duration = await loadDuration(for: url)
            total += size

            let recording = SavedRecording(
                id: UUID(),
                url: url,
                title: url.deletingPathExtension().lastPathComponent,
                createdAt: created,
                duration: duration,
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

    func trim(_ recording: SavedRecording, from start: TimeInterval, to end: TimeInterval) async throws -> SavedRecording {
        let asset = AVURLAsset(url: recording.url)
        let durationTime = try await asset.load(.duration)
        let totalDuration = max(durationTime.seconds, 0)
        let clampedStart = max(0, min(start, totalDuration))
        let clampedEnd = max(0, min(end, totalDuration))

        guard clampedEnd - clampedStart >= 0.1 else {
            throw TrimError.invalidRange
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw TrimError.exporterUnavailable
        }

        let outputURL = uniqueTrimmedURL(for: recording)
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        exporter.outputURL = outputURL
        if exporter.supportedFileTypes.contains(.mov) {
            exporter.outputFileType = .mov
        } else if let firstType = exporter.supportedFileTypes.first {
            exporter.outputFileType = firstType
        } else {
            throw TrimError.unsupportedFileType
        }
        exporter.shouldOptimizeForNetworkUse = false
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: clampedStart, preferredTimescale: 600),
            end: CMTime(seconds: clampedEnd, preferredTimescale: 600)
        )

        try await export(exporter: exporter)
        await refresh()

        guard let refreshed = recordings.first(where: { $0.url == outputURL }) else {
            throw TrimError.missingOutputURL
        }
        return refreshed
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

    private func loadDuration(for url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            guard duration.isNumeric else { return nil }
            return duration.seconds
        } catch {
            return nil
        }
    }

    private func uniqueTrimmedURL(for recording: SavedRecording) -> URL {
        let parent = recording.url.deletingLastPathComponent()
        let ext = recording.url.pathExtension
        let base = recording.url.deletingPathExtension().lastPathComponent + "_trimmed"
        var attempt = 0

        while true {
            let suffix = attempt == 0 ? "" : "_\(attempt)"
            let candidate = parent.appendingPathComponent(base + suffix).appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            attempt += 1
        }
    }

    private func export(exporter: AVAssetExportSession) async throws {
        let sessionBox = ExportSessionBox(exporter)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionBox.session.exportAsynchronously {
                switch sessionBox.session.status {
                case .completed:
                    continuation.resume()
                case .failed:
                    continuation.resume(
                        throwing: TrimError.exportFailed(
                            sessionBox.session.error?.localizedDescription ?? "Unknown error."
                        )
                    )
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    continuation.resume(
                        throwing: TrimError.exportFailed(
                            "Export finished in unexpected state: \(sessionBox.session.status.rawValue)"
                        )
                    )
                }
            }
        }
    }
}

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
