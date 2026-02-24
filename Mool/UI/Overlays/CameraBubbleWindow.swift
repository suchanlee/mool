import AppKit
import SwiftUI

// MARK: - Camera Bubble Window

/// A draggable, resizable floating window showing the live camera feed.
final class CameraBubbleWindow: NSPanel {
    private let minimumBubbleSize: CGFloat = 100
    private let maximumBubbleSize: CGFloat = 400

    override var canBecomeKey: Bool {
        true
    }

    init(cameraManager: any CameraManaging) {
        let defaultSize: CGFloat = 200
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: defaultSize, height: defaultSize),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isMovableByWindowBackground = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false

        let view = CameraBubbleView(
            cameraManager: cameraManager,
            onMoveBy: { [weak self] deltaX, deltaY in
                self?.moveBy(deltaX: deltaX, deltaY: deltaY)
            },
            onResizeBy: { [weak self] delta in
                self?.resizeBy(delta: delta)
            }
        )
        contentView = NSHostingView(rootView: view)

        // Default position: bottom-right corner of main screen
        if let screen = NSScreen.main {
            let margin: CGFloat = 24
            let x = screen.visibleFrame.maxX - defaultSize - margin
            let y = screen.visibleFrame.minY + margin
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    private func moveBy(deltaX: CGFloat, deltaY: CGFloat) {
        var nextFrame = frame
        nextFrame.origin.x += deltaX
        nextFrame.origin.y -= deltaY
        setFrame(clampedToVisibleFrame(nextFrame), display: true)
    }

    private func resizeBy(delta: CGFloat) {
        var nextFrame = frame
        let targetSize = min(max(nextFrame.width + delta, minimumBubbleSize), maximumBubbleSize)
        let appliedDelta = targetSize - nextFrame.width
        guard abs(appliedDelta) > 0.01 else { return }

        nextFrame.size = NSSize(width: targetSize, height: targetSize)
        // Grow/shrink from bottom-right drag while keeping top edge anchored.
        nextFrame.origin.y -= appliedDelta

        setFrame(clampedToVisibleFrame(nextFrame), display: true)
    }

    private func clampedToVisibleFrame(_ candidate: NSRect) -> NSRect {
        guard let visible = activeVisibleFrame() else { return candidate }
        var frame = candidate

        frame.origin.x = min(max(frame.origin.x, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visible.minY), visible.maxY - frame.height)

        return frame
    }

    private func activeVisibleFrame() -> NSRect? {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.visibleFrame.contains(center) }) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
    }
}
