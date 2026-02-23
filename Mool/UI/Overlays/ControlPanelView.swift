import SwiftUI

// MARK: - Control Panel View

/// The main recording HUD shown as a floating overlay during recording.
struct ControlPanelView: View {
    @Environment(RecordingEngine.self) private var engine
    @Bindable var annotationManager: AnnotationManager

    init(annotationManager: AnnotationManager) {
        self.annotationManager = annotationManager
    }

    var body: some View {
        HStack(spacing: 12) {
            // Recording indicator
            recordingIndicator

            Divider().frame(height: 28)

            // Timer
            Text(formattedTime)
                .monospacedDigit()
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .frame(minWidth: 52)

            Divider().frame(height: 28)

            // Controls
            HStack(spacing: 8) {
                // Pause / Resume
                if engine.state == .recording || engine.state == .paused {
                    HUDButton(
                        icon: engine.state == .paused ? "play.fill" : "pause.fill",
                        tint: .white
                    ) {
                        if engine.state == .paused {
                            engine.resumeRecording()
                        } else {
                            engine.pauseRecording()
                        }
                    }
                    .accessibilityIdentifier(engine.state == .paused ? "hud.resume" : "hud.pause")
                }

                // Stop
                HUDButton(icon: "stop.fill", tint: .red) {
                    Task { await engine.stopRecording() }
                }
                .accessibilityIdentifier("hud.stop")

                // Annotate toggle
                HUDButton(
                    icon: "pencil",
                    tint: annotationManager.isAnnotating ? .yellow : .white,
                    isActive: annotationManager.isAnnotating
                ) {
                    annotationManager.isAnnotating.toggle()
                }
                .accessibilityIdentifier("hud.annotate")
            }

            // Annotation tools (shown when annotating)
            if annotationManager.isAnnotating {
                Divider().frame(height: 28)
                annotationToolbar
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var recordingIndicator: some View {
        switch engine.state {
        case .countdown(let n):
            Text("\(n)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(.red, in: Circle())
        case .recording:
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .modifier(PulsingModifier())
        case .paused:
            Image(systemName: "pause.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 14))
        default:
            EmptyView()
        }
    }

    private var annotationToolbar: some View {
        HStack(spacing: 6) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                HUDButton(
                    icon: tool.iconName,
                    tint: annotationManager.selectedTool == tool ? .yellow : .white,
                    isActive: annotationManager.selectedTool == tool
                ) {
                    annotationManager.selectedTool = tool
                }
                .accessibilityIdentifier("hud.tool.\(tool)")
            }

            // Color picker
            ColorPicker("", selection: $annotationManager.selectedColor)
                .labelsHidden()
                .frame(width: 24, height: 24)

            // Clear
            HUDButton(icon: "trash", tint: .white) {
                annotationManager.clearAll()
            }
        }
    }

    private var formattedTime: String {
        let t = Int(engine.elapsedTime)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - HUD Button

struct HUDButton: View {
    let icon: String
    var tint: Color = .white
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(
                    isActive
                        ? AnyShapeStyle(tint.opacity(0.2))
                        : AnyShapeStyle(Color.white.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pulsing Modifier

struct PulsingModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    scale = 1.4
                }
            }
    }
}
