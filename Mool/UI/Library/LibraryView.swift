import AppKit
import AVFoundation
import AVKit
import SwiftUI

// MARK: - Library View

struct LibraryView: View {
    @Environment(StorageManager.self) var storageManager

    @State private var selectedRecording: SavedRecording?
    @State private var showingDeleteConfirm = false
    @State private var renamingRecording: SavedRecording?
    @State private var player: AVPlayer?
    @State private var isEditing = false

    var body: some View {
        NavigationSplitView {
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
            if let recording = selectedRecording {
                VideoDetailView(
                    recording: recording,
                    player: $player,
                    isEditing: $isEditing,
                    onSaveEditedVersion: { start, end, playbackRate in
                        let edited = try await storageManager.createEditedVersion(
                            recording,
                            from: start,
                            to: end,
                            playbackRate: playbackRate
                        )
                        await MainActor.run {
                            selectedRecording = edited
                        }
                    }
                )
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
        .onChange(of: selectedRecording?.id) { _, _ in
            isEditing = false
        }
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
            Button(isEditing ? "Exit Edit" : "Edit") {
                isEditing.toggle()
            }
            .disabled((recording.duration ?? 0) < 0.1)

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
    @Binding var isEditing: Bool
    let onSaveEditedVersion: (_ start: TimeInterval, _ end: TimeInterval, _ playbackRate: Double) async throws -> Void

    @State private var editStart: Double = 0
    @State private var editEnd: Double = 0
    @State private var editPlaybackRate: Double = 1.0
    @State private var thumbnails: [NSImage] = []
    @State private var isSavingEdit = false
    @State private var editErrorMessage: String?

    private let minimumTrimSpan: Double = 0.1
    private let playbackRateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let editControlRowHeight: CGFloat = 40
    private let editControlSpacing: CGFloat = 10
    private let editControlColumnWidth: CGFloat = 170

    private var timelineHeight: CGFloat {
        (editControlRowHeight * 3) + (editControlSpacing * 2)
    }

    private var totalDuration: Double {
        let recordedDuration = recording.duration ?? 0
        let playerDuration = player?.currentItem?.duration.seconds ?? 0
        let resolved = recordedDuration > 0 ? recordedDuration : playerDuration
        return max(resolved, 0)
    }

    private var isPlaying: Bool {
        player?.timeControlStatus == .playing
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VideoPlayer(player: player)

            if isEditing {
                editOverlay
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isEditing)
        .task(id: recording.url) {
            loadRecording(recording.url)
            resetEditorState()
            await generateThumbnailsIfNeeded(force: true)
        }
        .onChange(of: isEditing) { _, editing in
            if editing {
                beginEditing()
            } else {
                endEditing()
            }
        }
        .onChange(of: editStart) { _, _ in
            guard isEditing else { return }
            synchronizeEditedRange()
        }
        .onChange(of: editEnd) { _, _ in
            guard isEditing else { return }
            synchronizeEditedRange()
        }
        .onChange(of: editPlaybackRate) { _, _ in
            guard isEditing else { return }
            applyPlaybackRateIfPlaying()
        }
        .onDisappear {
            cleanupPlayerState()
        }
    }

    private var editOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    togglePlayPauseInEditor()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(width: 64, height: timelineHeight)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                )

                TrimTimelineStrip(
                    thumbnails: thumbnails,
                    duration: max(totalDuration, minimumTrimSpan),
                    startTime: $editStart,
                    endTime: $editEnd,
                    minimumSpan: minimumTrimSpan
                )
                .frame(maxWidth: .infinity, minHeight: timelineHeight, maxHeight: timelineHeight)

                VStack(spacing: editControlSpacing) {
                    Menu {
                        Picker("Speed", selection: $editPlaybackRate) {
                            ForEach(playbackRateOptions, id: \.self) { rate in
                                Text(Self.speedLabel(rate)).tag(rate)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "speedometer")
                            Text(Self.speedLabel(editPlaybackRate))
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: editControlRowHeight)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveEditedVersion()
                    } label: {
                        Text(isSavingEdit ? "Saving..." : "Save")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: editControlRowHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingEdit || !canSaveEdit)

                    Button("Cancel") {
                        isEditing = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingEdit)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: editControlRowHeight)
                }
                .frame(width: editControlColumnWidth, height: timelineHeight, alignment: .top)
            }

            HStack {
                Text("Start: \(Self.formatTime(editStart))")
                Text("End: \(Self.formatTime(editEnd))")
                Text("Length: \(Self.formatTime(max(editEnd - editStart, 0)))")
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)

            if let editErrorMessage {
                Text(editErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }

    private var canSaveEdit: Bool {
        totalDuration >= minimumTrimSpan && (editEnd - editStart) >= minimumTrimSpan
    }

    @MainActor
    private func loadRecording(_ url: URL) {
        if player == nil {
            player = AVPlayer(url: url)
        } else {
            player?.replaceCurrentItem(with: AVPlayerItem(url: url))
        }

        player?.seek(to: .zero)
        player?.play()
    }

    @MainActor
    private func beginEditing() {
        guard totalDuration >= minimumTrimSpan else {
            isEditing = false
            return
        }

        resetEditorState()
        synchronizeEditedRange()
        player?.pause()

        Task {
            await generateThumbnailsIfNeeded(force: thumbnails.isEmpty)
        }
    }

    @MainActor
    private func endEditing() {
        player?.currentItem?.forwardPlaybackEndTime = .invalid
        editErrorMessage = nil
    }

    @MainActor
    private func resetEditorState() {
        let duration = totalDuration
        editStart = 0
        editEnd = duration
        editPlaybackRate = 1.0
        editErrorMessage = nil
        isSavingEdit = false
    }

    @MainActor
    private func synchronizeEditedRange() {
        let duration = totalDuration
        guard duration >= minimumTrimSpan else { return }

        editStart = clamp(editStart, min: 0, max: max(duration - minimumTrimSpan, 0))
        editEnd = clamp(editEnd, min: editStart + minimumTrimSpan, max: duration)

        guard let player else { return }

        player.currentItem?.forwardPlaybackEndTime = CMTime(seconds: editEnd, preferredTimescale: 600)

        let current = player.currentTime().seconds
        if current < editStart || current > editEnd {
            player.seek(to: CMTime(seconds: editStart, preferredTimescale: 600))
        }
    }

    @MainActor
    private func togglePlayPauseInEditor() {
        guard let player else { return }

        if player.timeControlStatus == .playing {
            player.pause()
            return
        }

        let current = player.currentTime().seconds
        if current < editStart || current >= editEnd {
            player.seek(to: CMTime(seconds: editStart, preferredTimescale: 600))
        }

        player.playImmediately(atRate: Float(editPlaybackRate))
    }

    @MainActor
    private func applyPlaybackRateIfPlaying() {
        guard let player, player.timeControlStatus == .playing else { return }
        player.playImmediately(atRate: Float(editPlaybackRate))
    }

    private func saveEditedVersion() {
        isSavingEdit = true
        editErrorMessage = nil

        Task {
            do {
                try await onSaveEditedVersion(editStart, editEnd, editPlaybackRate)
                await MainActor.run {
                    isSavingEdit = false
                    isEditing = false
                }
            } catch {
                await MainActor.run {
                    isSavingEdit = false
                    editErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func generateThumbnailsIfNeeded(force: Bool) async {
        guard force || thumbnails.isEmpty else { return }
        let url = recording.url
        let duration = max(totalDuration, minimumTrimSpan)
        let images = await Self.generateThumbnails(for: url, duration: duration, count: 14)
        await MainActor.run {
            thumbnails = images
        }
    }

    private func cleanupPlayerState() {
        player?.pause()
        player = nil
    }

    private static func generateThumbnails(for url: URL, duration: TimeInterval, count: Int) async -> [NSImage] {
        await Task.detached(priority: .userInitiated) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 220, height: 124)

            var images: [NSImage] = []
            let frameCount = max(count, 1)

            for index in 0 ..< frameCount {
                let progress = frameCount == 1 ? 0.0 : Double(index) / Double(frameCount - 1)
                let second = max(0, duration * progress)
                let time = CMTime(seconds: second, preferredTimescale: 600)

                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    images.append(NSImage(cgImage: cgImage, size: .zero))
                }
            }

            return images
        }.value
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    private static func speedLabel(_ rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))x"
        }
        return "\(rate.formatted(.number.precision(.fractionLength(0 ... 2))))x"
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Trim Timeline Strip

struct TrimTimelineStrip: View {
    let thumbnails: [NSImage]
    let duration: Double
    @Binding var startTime: Double
    @Binding var endTime: Double
    let minimumSpan: Double

    @State private var activeHandle: DragHandle?

    private enum DragHandle {
        case start
        case end
    }

    private let handleVisualWidth: CGFloat = 16
    private let handleHitThreshold: CGFloat = 26
    private let trackCornerRadius: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let startX = CGFloat(startProgress) * width
            let endX = CGFloat(endProgress) * width

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.25))

                thumbnailTrack(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous))

                Color.black.opacity(0.45)
                    .frame(width: max(startX, 0), height: height)

                Color.black.opacity(0.45)
                    .frame(width: max(width - endX, 0), height: height)
                    .offset(x: endX)

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.yellow, lineWidth: 3)
                    .frame(width: max(endX - startX, 18), height: max(height - 2, 1))
                    .offset(x: startX)

                handleView(height: height)
                    .offset(x: startX - handleVisualWidth / 2, y: 4)

                handleView(height: height)
                    .offset(x: endX - handleVisualWidth / 2, y: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .highPriorityGesture(trimDragGesture(width: width, startX: startX, endX: endX))
        }
    }

    private var startProgress: Double {
        clamp(startTime / max(duration, minimumSpan), min: 0, max: 1)
    }

    private var endProgress: Double {
        clamp(endTime / max(duration, minimumSpan), min: 0, max: 1)
    }

    @ViewBuilder
    private func thumbnailTrack(width: CGFloat, height: CGFloat) -> some View {
        let visibleCount = max(thumbnails.count, 12)
        let spacing: CGFloat = 1
        let totalSpacing = spacing * CGFloat(max(visibleCount - 1, 0))
        let itemWidth = max((width - totalSpacing) / CGFloat(visibleCount), 1)

        HStack(spacing: spacing) {
            ForEach(0 ..< visibleCount, id: \.self) { index in
                Group {
                    if index < thumbnails.count {
                        Image(nsImage: thumbnails[index])
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .frame(width: itemWidth, height: height)
                .clipped()
            }
        }
    }

    private func handleView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.yellow)
            .frame(width: handleVisualWidth, height: max(height - 8, 24))
            .overlay {
                VStack(spacing: 3) {
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 7, height: 2)
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 7, height: 2)
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 7, height: 2)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }

    private func trimDragGesture(width: CGFloat, startX: CGFloat, endX: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if activeHandle == nil {
                    let startDistance = abs(value.startLocation.x - startX)
                    let endDistance = abs(value.startLocation.x - endX)

                    guard min(startDistance, endDistance) <= handleHitThreshold else { return }
                    activeHandle = startDistance <= endDistance ? .start : .end
                }

                guard let activeHandle else { return }

                let progress = clamp(Double(value.location.x / width), min: 0, max: 1)
                let time = progress * duration

                switch activeHandle {
                case .start:
                    startTime = min(time, endTime - minimumSpan)
                case .end:
                    endTime = max(time, startTime + minimumSpan)
                }
            }
            .onEnded { _ in
                activeHandle = nil
            }
    }

    private func clamp(_ value: Double, min: Double, max: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
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
