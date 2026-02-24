import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import SwiftUI

private enum QuickCaptureTab: String, CaseIterable {
    case display = "Full screen"
    case window = "Window"
}

struct QuickRecorderPopoverView: View {
    @Environment(RecordingEngine.self) private var engine

    let onStartRecording: () -> Void
    let onCameraVisibilityChanged: () -> Void

    @State private var captureTab: QuickCaptureTab = .display
    @State private var cameras: [AVCaptureDevice] = []
    @State private var microphones: [AVCaptureDevice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceRow
            cameraRow
            microphoneRow
            systemAudioRow
            startButton
        }
        .padding(12)
        .frame(width: 332)
        .task {
            captureTab = engine.settings.selectedWindowID == nil ? .display : .window
            refreshInputDevices()
        }
    }

    private var sourceRow: some View {
        Menu {
            Section("Capture Type") {
                Button("Full screen") {
                    setCaptureTab(.display)
                }
                Button("Window") {
                    setCaptureTab(.window)
                }
            }

            if captureTab == .display {
                Section("Display") {
                    ForEach(Array(engine.availableSources.displays.enumerated()), id: \.offset) { idx, display in
                        Button(displayName(display, index: idx)) {
                            selectDisplay(index: idx)
                        }
                    }
                }
            } else {
                Section("Window") {
                    Button("No Window") {
                        engine.settings.selectedWindowID = nil
                        engine.settings.save()
                    }
                    ForEach(engine.availableSources.windows, id: \.windowID) { window in
                        Button(windowName(window)) {
                            engine.settings.selectedWindowID = window.windowID
                            engine.settings.save()
                        }
                    }
                }
            }
        } label: {
            RowCard(
                iconName: "display",
                iconColor: .primary,
                title: sourceTitle,
                subtitle: sourceSubtitle,
                trailing: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            )
        }
        .buttonStyle(.plain)
    }

    private var cameraRow: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Default Camera") {
                    engine.selectCameraDevice(uniqueID: nil)
                }
                ForEach(cameras, id: \.uniqueID) { camera in
                    Button(camera.localizedName) {
                        engine.selectCameraDevice(uniqueID: camera.uniqueID)
                    }
                }
            } label: {
                RowCard(
                    iconName: engine.settings.mode.includesCamera ? "video.fill" : "video.slash",
                    iconColor: engine.settings.mode.includesCamera ? .primary : .red.opacity(0.8),
                    title: engine.settings.mode.includesCamera ? selectedCameraName : "No Camera",
                    subtitle: engine.settings.mode.includesCamera ? "Click to change camera" : "Camera is turned off",
                    trailing: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .opacity(engine.settings.mode.includesCamera ? 1 : 0.35)
                    }
                )
            }
            .buttonStyle(.plain)
            .disabled(!engine.settings.mode.includesCamera)

            TogglePill(isOn: engine.settings.mode.includesCamera) {
                engine.setCameraEnabled(!engine.settings.mode.includesCamera)
                onCameraVisibilityChanged()
                refreshInputDevices()
            }
        }
    }

    private var microphoneRow: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Default Microphone") {
                    engine.selectMicrophoneDevice(uniqueID: nil)
                }
                ForEach(microphones, id: \.uniqueID) { microphone in
                    Button(microphone.localizedName) {
                        engine.selectMicrophoneDevice(uniqueID: microphone.uniqueID)
                    }
                }
            } label: {
                RowCard(
                    iconName: "mic.fill",
                    iconColor: .primary,
                    title: engine.settings.captureMicrophone ? selectedMicrophoneName : "Microphone Off",
                    subtitle: engine.settings.captureMicrophone ? "Click to change microphone" : "Microphone is disabled",
                    trailing: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .opacity(engine.settings.captureMicrophone ? 1 : 0.35)
                    }
                )
            }
            .buttonStyle(.plain)
            .disabled(!engine.settings.captureMicrophone)

            TogglePill(isOn: engine.settings.captureMicrophone) {
                engine.settings.captureMicrophone.toggle()
                engine.settings.save()
            }
        }
    }

    private var systemAudioRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 22, alignment: .center)
            Text("System Audio")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            TogglePill(isOn: engine.settings.captureSystemAudio) {
                engine.settings.captureSystemAudio.toggle()
                engine.settings.save()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }

    private var startButton: some View {
        Button(action: onStartRecording) {
            Text("Start recording")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 1.0, green: 0.47, blue: 0.25))
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
    }

    private var sourceTitle: String {
        captureTab.rawValue
    }

    private var sourceSubtitle: String {
        if captureTab == .display {
            let displays = engine.availableSources.displays
            guard !displays.isEmpty else { return "No displays available" }
            let idx = min(engine.settings.selectedDisplayIndex, displays.count - 1)
            return displayName(displays[idx], index: idx)
        }

        if let windowID = engine.settings.selectedWindowID,
           let window = engine.availableSources.windows.first(where: { $0.windowID == windowID })
        {
            return windowName(window)
        }
        return "No window selected"
    }

    private var selectedCameraName: String {
        if let uniqueID = engine.settings.selectedCameraUniqueID,
           let camera = cameras.first(where: { $0.uniqueID == uniqueID })
        {
            return camera.localizedName
        }
        return cameras.first?.localizedName ?? "Default Camera"
    }

    private var selectedMicrophoneName: String {
        if let uniqueID = engine.settings.selectedMicrophoneUniqueID,
           let microphone = microphones.first(where: { $0.uniqueID == uniqueID })
        {
            return microphone.localizedName
        }
        return microphones.first?.localizedName ?? "Default Microphone"
    }

    private func setCaptureTab(_ tab: QuickCaptureTab) {
        captureTab = tab
        if tab == .display {
            engine.settings.selectedWindowID = nil
        }
        engine.settings.save()
    }

    private func selectDisplay(index: Int) {
        engine.settings.selectedDisplayIndex = index
        engine.settings.selectedWindowID = nil
        engine.settings.save()
    }

    private func displayName(_ display: SCDisplay, index: Int) -> String {
        "Display \(index + 1) (\(Int(display.width))x\(Int(display.height)))"
    }

    private func windowName(_ window: SCWindow) -> String {
        window.title ?? window.owningApplication?.applicationName ?? "Window \(window.windowID)"
    }

    private func refreshInputDevices() {
        cameras = engine.availableCameraDevices()
        microphones = engine.availableMicrophoneDevices()
    }
}

private struct RowCard<Trailing: View>: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.12))
        )
    }
}

private struct TogglePill: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(isOn ? "On" : "Off")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(isOn ? Color(red: 0.22, green: 0.78, blue: 0.86) : Color(red: 0.94, green: 0.36, blue: 0.12))
                )
        }
        .buttonStyle(.plain)
    }
}
