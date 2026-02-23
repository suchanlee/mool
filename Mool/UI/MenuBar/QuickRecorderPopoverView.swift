import AVFoundation
import CoreGraphics
import SwiftUI

private enum QuickCaptureTab: String, CaseIterable {
    case display = "Display"
    case window = "Window"
}

struct QuickRecorderPopoverView: View {
    @Environment(RecordingEngine.self) private var engine

    let onStartRecording: () -> Void
    let onOpenLibrary: () -> Void
    let onOpenSettings: () -> Void

    @State private var captureTab: QuickCaptureTab = .display
    @State private var cameras: [AVCaptureDevice] = []
    @State private var microphones: [AVCaptureDevice] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            sourceSection
            cameraSection
            audioSection
            actionSection
        }
        .padding(12)
        .frame(width: 320)
        .task {
            captureTab = engine.settings.selectedWindowID == nil ? .display : .window
            await engine.prepareQuickRecorderContext()
            refreshInputDevices()
        }
        .onDisappear {
            engine.teardownQuickRecorderContext()
        }
    }

    private var header: some View {
        HStack {
            Text("Mool Recorder")
                .font(.headline)
            Spacer()
            Button("Library", action: onOpenLibrary)
                .buttonStyle(.link)
            Button("Settings", action: onOpenSettings)
                .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Video Source")
                .font(.subheadline.weight(.semibold))

            Picker("Source Type", selection: $captureTab) {
                ForEach(QuickCaptureTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: captureTab) { _, newValue in
                if newValue == .display {
                    engine.settings.selectedWindowID = nil
                }
                engine.settings.save()
            }

            if captureTab == .display {
                Picker("Display", selection: Binding(
                    get: { engine.settings.selectedDisplayIndex },
                    set: { newValue in
                        engine.settings.selectedDisplayIndex = newValue
                        engine.settings.selectedWindowID = nil
                        engine.settings.save()
                    }
                )) {
                    ForEach(Array(engine.availableSources.displays.enumerated()), id: \.offset) { idx, display in
                        Text("Display \(idx + 1) (\(Int(display.width))x\(Int(display.height)))").tag(idx)
                    }
                }
                .labelsHidden()
            } else {
                Picker("Window", selection: Binding(
                    get: { engine.settings.selectedWindowID },
                    set: { newValue in
                        engine.settings.selectedWindowID = newValue
                        engine.settings.save()
                    }
                )) {
                    Text("No Window")
                        .tag(Optional<CGWindowID>.none)
                    ForEach(engine.availableSources.windows, id: \.windowID) { window in
                        Text(window.title ?? window.owningApplication?.applicationName ?? "Window \(window.windowID)")
                            .tag(Optional(window.windowID))
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Camera", isOn: Binding(
                get: { engine.settings.mode.includesCamera },
                set: { newValue in
                    engine.setCameraEnabled(newValue)
                    refreshInputDevices()
                }
            ))

            HStack(spacing: 10) {
                if engine.settings.mode.includesCamera {
                    CameraPreviewRepresentable(previewLayer: engine.cameraManager.previewLayer)
                        .frame(width: 92, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 92, height: 64)
                        .overlay(Text("Off").font(.caption).foregroundStyle(.secondary))
                }

                Picker("Camera Device", selection: Binding(
                    get: { engine.settings.selectedCameraUniqueID },
                    set: { newValue in
                        engine.selectCameraDevice(uniqueID: newValue)
                    }
                )) {
                    Text("Default Camera").tag(Optional<String>.none)
                    ForEach(cameras, id: \.uniqueID) { camera in
                        Text(camera.localizedName).tag(Optional(camera.uniqueID))
                    }
                }
                .labelsHidden()
                .disabled(!engine.settings.mode.includesCamera)
            }
        }
    }

    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Microphone", isOn: Binding(
                get: { engine.settings.captureMicrophone },
                set: { newValue in
                    engine.settings.captureMicrophone = newValue
                    engine.settings.save()
                }
            ))

            Picker("Microphone Device", selection: Binding(
                get: { engine.settings.selectedMicrophoneUniqueID },
                set: { newValue in
                    engine.selectMicrophoneDevice(uniqueID: newValue)
                }
            )) {
                Text("Default Microphone").tag(Optional<String>.none)
                ForEach(microphones, id: \.uniqueID) { microphone in
                    Text(microphone.localizedName).tag(Optional(microphone.uniqueID))
                }
            }
            .labelsHidden()
            .disabled(!engine.settings.captureMicrophone)

            Toggle("System Audio", isOn: Binding(
                get: { engine.settings.captureSystemAudio },
                set: { newValue in
                    engine.settings.captureSystemAudio = newValue
                    engine.settings.save()
                }
            ))
        }
    }

    private var actionSection: some View {
        Button(action: onStartRecording) {
            Text("Start Recording")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    private func refreshInputDevices() {
        cameras = engine.availableCameraDevices()
        microphones = engine.availableMicrophoneDevices()
    }
}
