import AVKit
import SwiftUI

// MARK: - Library View

struct LibraryView: View {
    @Environment(StorageManager.self) var storageManager
    @Environment(RecordingEngine.self) var engine

    @State private var selectedRecording: SavedRecording?
    @State private var showingDeleteConfirm = false
    @State private var renamingRecording: SavedRecording?
    @State private var newName: String = ""
    @State private var player: AVPlayer?

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
                VideoDetailView(recording: recording, player: $player)
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
            Button("Rename") {
                renamingRecording = recording
            }
            Button("Reveal in Finder") {
                storageManager.revealInFinder(recording)
            }
            Button("Copy Path") {
                storageManager.copyPath(recording)
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

    var body: some View {
        VideoPlayer(player: player ?? AVPlayer())
            .onAppear {
                player = AVPlayer(url: recording.url)
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
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
