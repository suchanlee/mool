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
    @State private var isPlaying = false
    @State private var currentPlaybackTime: Double = 0

    private let minimumTrimSpan: Double = 0.1
    private let playbackRateOptions: [Double] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let editControlRowHeight: CGFloat = 32
    private let editControlSpacing: CGFloat = 8
    private let editControlColumnWidth: CGFloat = 145
    private let editControlCornerRadius: CGFloat = 10
    private let playheadTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    private var timelineHeight: CGFloat {
        (editControlRowHeight * 3) + (editControlSpacing * 2)
    }

    private var totalDuration: Double {
        let recordedDuration = recording.duration ?? 0
        let playerDuration = player?.currentItem?.duration.seconds ?? 0
        let resolved = recordedDuration > 0 ? recordedDuration : playerDuration
        return max(resolved, 0)
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
        .onReceive(playheadTimer) { _ in
            updatePlaybackState()
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
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    .frame(width: 64, height: timelineHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                TrimTimelineStrip(
                    thumbnails: thumbnails,
                    duration: max(totalDuration, minimumTrimSpan),
                    startTime: $editStart,
                    endTime: $editEnd,
                    minimumSpan: minimumTrimSpan,
                    playheadTime: currentPlaybackTime
                )
                .frame(maxWidth: .infinity, minHeight: timelineHeight, maxHeight: timelineHeight)

                VStack(spacing: editControlSpacing) {
                    Menu {
                        ForEach(playbackRateOptions, id: \.self) { rate in
                            Button {
                                editPlaybackRate = rate
                            } label: {
                                if editPlaybackRate == rate {
                                    Label(Self.speedLabel(rate), systemImage: "checkmark")
                                } else {
                                    Text(Self.speedLabel(rate))
                                }
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
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: editControlRowHeight, maxHeight: editControlRowHeight)
                        .background(
                            Color.white.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: editControlCornerRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: editControlCornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        saveEditedVersion()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: editControlCornerRadius, style: .continuous)
                                .fill(canSaveEdit && !isSavingEdit ? Color.accentColor : Color.accentColor.opacity(0.5))
                            Text(isSavingEdit ? "Saving..." : "Save")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, minHeight: editControlRowHeight, maxHeight: editControlRowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingEdit || !canSaveEdit)

                    Button {
                        isEditing = false
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: editControlCornerRadius, style: .continuous)
                                .fill(Color.white.opacity(isSavingEdit ? 0.05 : 0.1))
                            RoundedRectangle(cornerRadius: editControlCornerRadius, style: .continuous)
                                .strokeBorder(.white.opacity(0.14), lineWidth: 0.5)
                            Text("Cancel")
                        }
                        .frame(maxWidth: .infinity, minHeight: editControlRowHeight, maxHeight: editControlRowHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingEdit)
                    .font(.system(size: 13, weight: .semibold))
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
        currentPlaybackTime = 0
        isPlaying = true
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
        isPlaying = false

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
        currentPlaybackTime = 0
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
            currentPlaybackTime = editStart
        }
    }

    @MainActor
    private func togglePlayPauseInEditor() {
        guard let player else { return }

        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
            return
        }

        let current = player.currentTime().seconds
        if current < editStart || current >= editEnd {
            player.seek(to: CMTime(seconds: editStart, preferredTimescale: 600))
        }

        player.playImmediately(atRate: Float(editPlaybackRate))
        isPlaying = true
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
        isPlaying = false
    }

    @MainActor
    private func updatePlaybackState() {
        guard let player else {
            isPlaying = false
            return
        }

        isPlaying = player.timeControlStatus == .playing
        let now = player.currentTime().seconds
        if now.isFinite {
            currentPlaybackTime = max(0, now)
        }

        if isEditing, now >= editEnd, isPlaying {
            player.pause()
            isPlaying = false
            currentPlaybackTime = editEnd
        }
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
    let playheadTime: Double?

    private let handleVisualWidth: CGFloat = 18
    private let handleHitAreaWidth: CGFloat = 44
    private let trackCornerRadius: CGFloat = 10
    private let horizontalPadding: CGFloat = 20

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let trackWidth = max(width - horizontalPadding * 2, 1)
            let trackMinX = horizontalPadding
            let trackMaxX = trackMinX + trackWidth
            let startX = trackMinX + CGFloat(startProgress) * trackWidth
            let endX = trackMinX + CGFloat(endProgress) * trackWidth
            let startHandleX = max(trackMinX, startX - handleVisualWidth / 2)
            let endHandleX = min(trackMaxX - handleVisualWidth, endX - handleVisualWidth / 2)
            let hitInset = (handleHitAreaWidth - handleVisualWidth) / 2
            let startHitX = max(trackMinX, startHandleX - hitInset)
            let endHitX = min(trackMaxX - handleHitAreaWidth, endHandleX - hitInset)
            let stripMinXGlobal = proxy.frame(in: .global).minX

            ZStack(alignment: .leading) {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous)
                        .fill(Color.black.opacity(0.25))

                    thumbnailTrack(width: trackWidth, height: height)
                        .clipShape(RoundedRectangle(cornerRadius: trackCornerRadius, style: .continuous))

                    Color.black.opacity(0.45)
                        .frame(width: max(startX - trackMinX, 0), height: height)

                    Color.black.opacity(0.45)
                        .frame(width: max((trackMinX + trackWidth) - endX, 0), height: height)
                        .offset(x: endX - trackMinX)

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.yellow, lineWidth: 3)
                        .frame(width: max(endX - startX, handleVisualWidth), height: height)
                        .offset(x: startX - trackMinX)

                    if playheadTime != nil {
                        Capsule(style: .continuous)
                            .fill(.white.opacity(0.92))
                            .frame(width: 2, height: height + 4)
                            .offset(x: (playheadX(trackMinX: trackMinX, trackWidth: trackWidth, height: height) - trackMinX) - 1, y: -2)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                    }
                }
                .frame(width: trackWidth, height: height)
                .offset(x: trackMinX)
                .zIndex(0)

                handleView(height: height)
                    .offset(x: startHandleX)
                    .zIndex(2)

                handleView(height: height)
                    .offset(x: endHandleX)
                    .zIndex(2)

                handleHitArea(height: height)
                    .offset(x: startHitX)
                    .zIndex(3)
                    .highPriorityGesture(
                        startHandleDrag(
                            stripMinXGlobal: stripMinXGlobal,
                            trackMinX: trackMinX,
                            trackWidth: trackWidth
                        )
                    )

                handleHitArea(height: height)
                    .offset(x: endHitX)
                    .zIndex(3)
                    .highPriorityGesture(
                        endHandleDrag(
                            stripMinXGlobal: stripMinXGlobal,
                            trackMinX: trackMinX,
                            trackWidth: trackWidth
                        )
                    )
            }
            .contentShape(Rectangle())
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

    private func handleHitArea(height: CGFloat) -> some View {
        Color.black.opacity(0.001)
            .frame(width: handleHitAreaWidth, height: height + 10)
            .contentShape(Rectangle())
    }

    private func handleView(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.yellow)
            .frame(width: handleVisualWidth, height: max(height, 24))
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

    private func startHandleDrag(
        stripMinXGlobal: CGFloat,
        trackMinX: CGFloat,
        trackWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let localX = value.location.x - stripMinXGlobal
                let progress = clamp(Double((localX - trackMinX) / trackWidth), min: 0, max: 1)
                let time = progress * duration
                startTime = min(time, endTime - minimumSpan)
            }
    }

    private func endHandleDrag(
        stripMinXGlobal: CGFloat,
        trackMinX: CGFloat,
        trackWidth: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                let localX = value.location.x - stripMinXGlobal
                let progress = clamp(Double((localX - trackMinX) / trackWidth), min: 0, max: 1)
                let time = progress * duration
                endTime = max(time, startTime + minimumSpan)
            }
    }

    private func playheadX(trackMinX: CGFloat, trackWidth: CGFloat, height _: CGFloat) -> CGFloat {
        guard let playheadTime else { return trackMinX }
        let progress = clamp(playheadTime / max(duration, minimumSpan), min: 0, max: 1)
        return trackMinX + CGFloat(progress) * trackWidth
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
