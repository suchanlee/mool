import AppKit
import SwiftUI

// MARK: - Control Panel Window

/// A floating, non-activating panel that hosts the recording HUD.
/// Stays on top of all other windows without stealing keyboard focus.
final class ControlPanelWindow: NSPanel {
    init(
        recordingEngine: RecordingEngine,
        annotationManager: AnnotationManager,
        onStopRequested: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 68),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Appearance
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false

        // Content
        let view = ControlPanelView(
            annotationManager: annotationManager,
            onStopRequested: onStopRequested
        )
        .environment(recordingEngine)
        contentView = NSHostingView(rootView: view)

        // Position: bottom-center of main screen
        if let screen = NSScreen.main {
            let cx = screen.visibleFrame.midX - frame.width / 2
            let cy = screen.visibleFrame.minY + 40
            setFrameOrigin(NSPoint(x: cx, y: cy))
        }
    }
}
