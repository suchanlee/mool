import AppKit
import SwiftUI

// MARK: - Camera Bubble Window

/// A draggable, resizable floating window showing the live camera feed.
final class CameraBubbleWindow: NSPanel {

    private var dragStart: NSPoint = .zero
    private var frameOnDragStart: NSRect = .zero

    init(cameraManager: CameraManager) {
        let defaultSize: CGFloat = 200
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: defaultSize, height: defaultSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false

        let view = CameraBubbleView(cameraManager: cameraManager)
        contentView = NSHostingView(rootView: view)

        // Default position: bottom-right corner of main screen
        if let screen = NSScreen.main {
            let margin: CGFloat = 24
            let x = screen.visibleFrame.maxX - defaultSize - margin
            let y = screen.visibleFrame.minY + margin
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
