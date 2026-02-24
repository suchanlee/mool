import AppKit
import SwiftUI

// MARK: - Camera Bubble Window

/// A draggable, resizable floating window showing the live camera feed.
final class CameraBubbleWindow: NSPanel {
    private let minimumBubbleSize: CGFloat = 100
    private let maximumBubbleSize: CGFloat = 400
    private var moveAnchorMouseLocation: NSPoint?
    private var moveAnchorFrame: NSRect?
    private var resizeAnchorMouseLocation: NSPoint?
    private var resizeAnchorFrame: NSRect?

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
            onMoveBegan: { [weak self] mouseLocation in
                self?.beginMove(at: mouseLocation)
            },
            onMoveChanged: { [weak self] mouseLocation in
                self?.move(to: mouseLocation)
            },
            onMoveEnded: { [weak self] in
                self?.endMove()
            },
            onResizeBegan: { [weak self] mouseLocation in
                self?.beginResize(at: mouseLocation)
            },
            onResizeChanged: { [weak self] mouseLocation in
                self?.resize(to: mouseLocation)
            },
            onResizeEnded: { [weak self] in
                self?.endResize()
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

    private func beginMove(at mouseLocation: NSPoint) {
        moveAnchorMouseLocation = mouseLocation
        moveAnchorFrame = frame
    }

    private func move(to mouseLocation: NSPoint) {
        guard let anchorMouse = moveAnchorMouseLocation, let anchorFrame = moveAnchorFrame else { return }
        let deltaX = mouseLocation.x - anchorMouse.x
        let deltaY = mouseLocation.y - anchorMouse.y

        var nextFrame = anchorFrame
        nextFrame.origin.x += deltaX
        nextFrame.origin.y += deltaY
        setFrame(clampedToVisibleFrame(nextFrame), display: true)
    }

    private func endMove() {
        moveAnchorMouseLocation = nil
        moveAnchorFrame = nil
    }

    private func beginResize(at mouseLocation: NSPoint) {
        resizeAnchorMouseLocation = mouseLocation
        resizeAnchorFrame = frame
    }

    private func resize(to mouseLocation: NSPoint) {
        guard let anchorMouse = resizeAnchorMouseLocation, let anchorFrame = resizeAnchorFrame else { return }
        let deltaX = mouseLocation.x - anchorMouse.x
        let deltaY = mouseLocation.y - anchorMouse.y
        let sizeDelta = max(deltaX, -deltaY)

        let maxSizeByBounds: CGFloat = {
            guard let visible = activeVisibleFrame() else { return maximumBubbleSize }
            // Keep top-left fixed while resizing from bottom-right.
            let availableToRight = visible.maxX - anchorFrame.minX
            let availableToBottom = anchorFrame.maxY - visible.minY
            return min(maximumBubbleSize, availableToRight, availableToBottom)
        }()

        let targetSize = min(max(anchorFrame.width + sizeDelta, minimumBubbleSize), maxSizeByBounds)
        guard abs(targetSize - anchorFrame.width) > 0.01 else { return }

        var nextFrame = anchorFrame
        nextFrame.size = NSSize(width: targetSize, height: targetSize)
        nextFrame.origin.y = anchorFrame.maxY - targetSize

        setFrame(clampedToVisibleFrame(nextFrame), display: true)
    }

    private func endResize() {
        resizeAnchorMouseLocation = nil
        resizeAnchorFrame = nil
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
