import ScreenCaptureKit
import SwiftUI

// MARK: - Source Picker View

/// Pre-recording sheet: choose mode, display/window, and kick off the recording.
struct SourcePickerView: View {
    @Bindable var engine: RecordingEngine
    var onStartRecording: () -> Void
    var onCancel: () -> Void

    @State private var isLoadingSources = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 20)

            Divider()

            // Content
            ScrollView {
                VStack(spacing: 20) {
                    modePicker
                    if engine.settings.mode.includesScreen {
                        sourcePicker
                    }
                    qualityPicker
                    audioPicker
                }
                .padding(24)
            }

            Divider()

            // Actions
            actionBar
                .padding(16)
        }
        .frame(width: 540, height: 540)
        .task {
            isLoadingSources = true
            await engine.availableSources.refresh()
            isLoadingSources = false
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("New Recording")
                    .font(.title2.bold())
                Text("Choose what to capture")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            Spacer()
            // Mode icons
            HStack(spacing: 4) {
                ForEach(RecordingMode.allCases, id: \.self) { mode in
                    ModeChip(mode: mode, isSelected: engine.settings.mode == mode) {
                        engine.settings.mode = mode
                    }
                }
            }
        }
    }

    // MARK: - Mode picker (large cards)

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Mode", systemImage: "rectangle.on.rectangle")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(RecordingMode.allCases, id: \.self) { mode in
                    ModeCard(mode: mode, isSelected: engine.settings.mode == mode) {
                        withAnimation(.spring(duration: 0.2)) {
                            engine.settings.mode = mode
                        }
                    }
                }
            }
        }
    }

    // MARK: - Source picker (display / window tabs)

    @State private var sourceTab: SourceTab = .display

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Capture Source", systemImage: "display")
                .font(.headline)

            Picker("Source Type", selection: $sourceTab) {
                Text("Display").tag(SourceTab.display)
                Text("Window").tag(SourceTab.window)
            }
            .pickerStyle(.segmented)

            if isLoadingSources {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(height: 80)
            } else if sourceTab == .display {
                displayGrid
            } else {
                windowList
            }
        }
    }

    private var displayGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
            ForEach(Array(engine.availableSources.displays.enumerated()), id: \.offset) { idx, display in
                DisplayTile(
                    display: display,
                    isSelected: engine.settings.selectedDisplayIndex == idx,
                    action: { engine.settings.selectedDisplayIndex = idx }
                )
            }
        }
        .overlay {
            if engine.availableSources.displays.isEmpty {
                Text("No displays found")
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            }
        }
    }

    private var windowList: some View {
        VStack(spacing: 4) {
            ForEach(engine.availableSources.windows.prefix(12), id: \.windowID) { window in
                WindowRow(
                    window: window,
                    isSelected: engine.settings.selectedWindowID == window.windowID,
                    action: { engine.settings.selectedWindowID = window.windowID }
                )
            }
        }
        .overlay {
            if engine.availableSources.windows.isEmpty {
                Text("No windows found")
                    .foregroundStyle(.secondary)
                    .frame(height: 80)
            }
        }
    }

    // MARK: - Quality

    private var qualityPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quality", systemImage: "sparkles")
                .font(.headline)
            HStack(spacing: 8) {
                ForEach(VideoQuality.allCases, id: \.self) { q in
                    QualityChip(quality: q, isSelected: engine.settings.quality == q) {
                        engine.settings.quality = q
                    }
                }
            }
        }
    }

    // MARK: - Audio

    private var audioPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Audio", systemImage: "waveform")
                .font(.headline)
            HStack(spacing: 16) {
                Toggle("Microphone", isOn: $engine.settings.captureMicrophone)
                    .toggleStyle(.checkbox)
                Toggle("System Audio", isOn: $engine.settings.captureSystemAudio)
                    .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Action bar

    private var actionBar: some View {
        HStack {
            // Countdown stepper
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .foregroundStyle(.secondary)
                Stepper(
                    engine.settings.countdownDuration == 0
                        ? "No countdown"
                        : "\(engine.settings.countdownDuration)s countdown",
                    value: $engine.settings.countdownDuration,
                    in: 0...10
                )
                .fixedSize()
            }

            Spacer()

            Button("Cancel", action: onCancel)
                .keyboardShortcut(.escape, modifiers: [])

            Button(action: onStartRecording) {
                Label("Record", systemImage: "record.circle.fill")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.return, modifiers: [])
            .disabled(engine.settings.mode.includesScreen && engine.availableSources.displays.isEmpty && engine.settings.selectedWindowID == nil)
            .accessibilityIdentifier("sourcePicker.record")
        }
    }
}

// MARK: - Supporting Types

private enum SourceTab: String, CaseIterable {
    case display = "Display"
    case window = "Window"
}

// MARK: - Mode Card

struct ModeCard: View {
    let mode: RecordingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: modeIcon)
                    .font(.system(size: 26))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.1),
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("modeCard.\(mode.rawValue)")
    }

    private var modeIcon: String {
        switch mode {
        case .screenAndCamera: "rectangle.inset.filled.on.rectangle"
        case .screenOnly: "rectangle.fill"
        case .cameraOnly: "camera.fill"
        }
    }
}

// MARK: - Mode Chip (header row)

private struct ModeChip: View {
    let mode: RecordingMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: chipIcon)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(6)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        }
        .buttonStyle(.plain)
        .help(mode.rawValue)
    }

    private var chipIcon: String {
        switch mode {
        case .screenAndCamera: "rectangle.inset.filled.on.rectangle"
        case .screenOnly: "rectangle.fill"
        case .cameraOnly: "camera.fill"
        }
    }
}

// MARK: - Display Tile

struct DisplayTile: View {
    let display: SCDisplay
    let isSelected: Bool
    let action: () -> Void

    // Extracted to help the type-checker
    private var previewBox: some View {
        let fillColor: Color = isSelected ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08)
        let strokeColor: Color = isSelected ? Color.accentColor : Color.secondary.opacity(0.2)
        let strokeWidth: CGFloat = isSelected ? 2 : 1
        let iconColor: Color = isSelected ? Color.accentColor : Color.secondary
        return RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(strokeColor, lineWidth: strokeWidth))
            .overlay(Image(systemName: "display").font(.system(size: 24)).foregroundStyle(iconColor))
            .aspectRatio(CGFloat(display.width) / CGFloat(display.height), contentMode: .fit)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                previewBox
                Text("Display \(display.displayID)")
                    .font(.caption.bold())
                Text("\(display.width) × \(display.height)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
            .background(
                isSelected ? Color.accentColor.opacity(0.05) : Color.clear,
                in: RoundedRectangle(cornerRadius: 10)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Window Row

struct WindowRow: View {
    let window: SCWindow
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "macwindow")
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(window.title ?? "Untitled")
                        .lineLimit(1)
                        .font(.system(size: 13))
                    if let appName = window.owningApplication?.applicationName {
                        Text(appName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(
                isSelected ? Color.accentColor.opacity(0.1) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quality Chip

private struct QualityChip: View {
    let quality: VideoQuality
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(quality.rawValue)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}
