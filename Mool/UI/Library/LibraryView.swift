import AVKit
import SwiftUI

// MARK: - Library View

struct LibraryView: View {
    @Environment(StorageManager.self) var storageManager
    @Environment(RecordingEngine.self) var engine

    @State private var selectedRecording: SavedRecording?
    @State private var showingDeleteConfirm = false
    @State private var renamingRecording: SavedRecording?
    @State private var trimmingRecording: SavedRecording?
    @State private var player: AVPlayer?
    @State private var playbackRate: Double = 1.0

    private let playbackRateOptions: [Double] = [0.5, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        NavigationSplitView {
            // Sidebar: recording list
            recordingList
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { Task { await storageManager.refresh() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
        } detail: {
            // Detail: video player
            if let recording = selectedRecording {
                VideoDetailView(recording: recording, player: $player, playbackRate: $playbackRate)
                    .toolbar {
                        recordingToolbar(recording)
                    }
            } else {
                ContentUnavailableView(
                    "No Recording Selected",
                    systemImage: "video.slash",
                    description: Text("Select a recording from the list.")
                )
            }
        }
        .task { await storageManager.refresh() }
        .sheet(item: $renamingRecording) { recording in
            RenameSheet(recording: recording, storageManager: storageManager)
        }
        .sheet(item: $trimmingRecording) { recording in
            TrimRecordingSheet(recording: recording, storageManager: storageManager) { trimmedRecording in
                selectedRecording = trimmedRecording
            }
        }
    }

    // MARK: - Recording List

    private var recordingList: some View {
        List(storageManager.recordings, selection: $selectedRecording) { recording in
            RecordingRow(recording: recording)
                .tag(recording)
        }
        .overlay {
            if storageManager.recordings.isEmpty {
                ContentUnavailableView(
                    "No Recordings Yet",
                    systemImage: "record.circle",
                    description: Text("Start recording from the menu bar.")
                )
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private func recordingToolbar(_ recording: SavedRecording) -> some ToolbarContent {
        ToolbarItemGroup {
            Menu {
                Picker("Playback Speed", selection: $playbackRate) {
                    ForEach(playbackRateOptions, id: \.self) { rate in
                        Text(Self.speedLabel(rate)).tag(rate)
                    }
                }
            } label: {
                Label(Self.speedLabel(playbackRate), systemImage: "speedometer")
            }

            Button("Rename") {
                renamingRecording = recording
            }
            Button("Reveal in Finder") {
                storageManager.revealInFinder(recording)
            }
            Button("Copy Path") {
                storageManager.copyPath(recording)
            }
            Button("Trim") {
                trimmingRecording = recording
            }
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Image(systemName: "trash")
            }
            .confirmationDialog(
                "Delete \"\(recording.title)\"?",
                isPresented: $showingDeleteConfirm
            ) {
                Button("Delete", role: .destructive) {
                    try? storageManager.delete(recording)
                    selectedRecording = nil
                }
            } message: {
                Text("This moves the file to the Trash.")
            }
        }
    }

    private static func speedLabel(_ rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))x"
        }
        return "\(rate.formatted(.number.precision(.fractionLength(0 ... 2))))x"
    }
}

// MARK: - Recording Row

struct RecordingRow: View {
    let recording: SavedRecording

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "video.fill")
                .foregroundStyle(.red)
                .frame(width: 32, height: 32)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 6) {
                    Text(recording.createdAt.formatted(date: .abbreviated, time: .shortened))
                    if let dur = recording.formattedDuration {
                        Text("·")
                        Text(dur)
                    }
                    Text("·")
                    Text(recording.formattedSize)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Video Detail View

struct VideoDetailView: View {
    let recording: SavedRecording
    @Binding var player: AVPlayer?
    @Binding var playbackRate: Double

    var body: some View {
        VideoPlayer(player: player)
            .task(id: recording.url) {
                loadRecording(recording.url)
            }
            .onChange(of: playbackRate) { _, _ in
                applyPlaybackRateIfPlaying()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }

    @MainActor
    private func loadRecording(_ url: URL) {
        if player == nil {
            player = AVPlayer(url: url)
        } else {
            player?.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
        player?.seek(to: .zero)
        player?.playImmediately(atRate: Float(playbackRate))
    }

    @MainActor
    private func applyPlaybackRateIfPlaying() {
        guard let player, player.timeControlStatus == .playing else { return }
        player.playImmediately(atRate: Float(playbackRate))
    }
}

// MARK: - Trim Sheet

struct TrimRecordingSheet: View {
    let recording: SavedRecording
    let storageManager: StorageManager
    let onTrimmed: (SavedRecording) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var trimStart: Double = 0
    @State private var trimEnd: Double = 0
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var totalDuration: Double {
        max(recording.duration ?? 0, 0)
    }

    private var selectedDuration: Double {
        max(trimEnd - trimStart, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trim Recording")
                .font(.headline)

            Text(recording.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if totalDuration > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Start")
                            Spacer()
                            Text(Self.formatTime(trimStart))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $trimStart,
                            in: 0 ... trimEnd,
                            step: 0.1
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("End")
                            Spacer()
                            Text(Self.formatTime(trimEnd))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: $trimEnd,
                            in: trimStart ... totalDuration,
                            step: 0.1
                        )
                    }

                    HStack {
                        Text("Selected")
                        Spacer()
                        Text(Self.formatTime(selectedDuration))
                            .monospacedDigit()
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                }
            } else {
                Text("Unable to load duration for this recording.")
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)

                Spacer()

                Button("Save Trim") {
                    saveTrim()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSaving || totalDuration <= 0 || selectedDuration < 0.1)
            }
        }
        .padding(20)
        .frame(minWidth: 430)
        .onAppear {
            trimStart = 0
            trimEnd = totalDuration
        }
    }

    private func saveTrim() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let trimmed = try await storageManager.trim(recording, from: trimStart, to: trimEnd)
                await MainActor.run {
                    isSaving = false
                    onTrimmed(trimmed)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Rename Sheet

struct RenameSheet: View {
    let recording: SavedRecording
    let storageManager: StorageManager
    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Rename Recording")
                .font(.headline)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack {
                Button("Cancel") { dismiss() }
                Button("Rename") {
                    Task {
                        try? await storageManager.rename(recording, to: name)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
        }
        .padding(24)
        .onAppear { name = recording.title }
    }
}
