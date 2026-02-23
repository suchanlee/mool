import SwiftUI

// MARK: - Permissions Onboarding View

/// Shown when launching for the first time, guides the user through
/// granting all required permissions.
struct PermissionsView: View {
    @Bindable var permissionManager: PermissionManager
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                    .padding(.top, 40)

                Text("Welcome to Mool")
                    .font(.largeTitle.bold())
                Text("Grant permissions so Mool can record your screen, camera, and audio.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Permission rows
            VStack(spacing: 12) {
                PermissionRow(
                    icon: "display",
                    title: "Screen Recording",
                    description: "Required to capture your screen.",
                    status: permissionManager.screenRecording,
                    action: { permissionManager.requestScreenRecording() }
                )

                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Required for webcam overlay.",
                    status: permissionManager.camera,
                    action: { Task { await permissionManager.requestCamera() } }
                )

                PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Required to record audio narration.",
                    status: permissionManager.microphone,
                    action: { Task { await permissionManager.requestMicrophone() } }
                )

                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Optional — enables cursor highlighting.",
                    status: permissionManager.accessibility,
                    action: { permissionManager.requestAccessibility() }
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Continue button
            Button(action: onComplete) {
                Text("Continue to Mool")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .disabled(!permissionManager.allGranted)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            if !permissionManager.allGranted {
                Text("Grant Screen Recording, Camera, and Microphone permissions to continue.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .frame(width: 500, height: 560)
        .task {
            await permissionManager.checkAllPermissions()
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            statusView
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .granted:
            Label("Granted", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption.bold())
        case .denied:
            Button("Open Settings", action: action)
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
        case .notDetermined:
            Button("Allow", action: action)
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.small)
        }
    }

    private var iconColor: Color {
        switch status {
        case .granted: .green
        case .denied: .orange
        case .notDetermined: .blue
        }
    }
}
