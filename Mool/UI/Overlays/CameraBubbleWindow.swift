import AppKit
import SwiftUI

// MARK: - Camera Bubble Window

enum CameraBubbleSizePreset: String, CaseIterable {
    case small
    case medium
    case large

    var sideLength: CGFloat {
        switch self {
        case .small: 160
        case .medium: 220
        case .large: 300
        }
    }

    var shortLabel: String {
        switch self {
        case .small: "S"
        case .medium: "M"
        case .large: "L"
        }
    }
}

/// A draggable floating window showing the live camera feed.
final class CameraBubbleWindow: NSPanel {
    private var moveAnchorMouseLocation: NSPoint?
    private var moveAnchorFrame: NSRect?
    var onFrameChanged: (() -> Void)?
    var onMoveStateChanged: ((Bool) -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    init(cameraManager: any CameraManaging) {
        let defaultSize = CameraBubbleSizePreset.medium.sideLength
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
        hasShadow = false
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
        onMoveStateChanged?(true)
    }

    private func move(to mouseLocation: NSPoint) {
        guard let anchorMouse = moveAnchorMouseLocation, let anchorFrame = moveAnchorFrame else { return }
        let deltaX = mouseLocation.x - anchorMouse.x
        let deltaY = mouseLocation.y - anchorMouse.y

        var nextFrame = anchorFrame
        nextFrame.origin.x += deltaX
        nextFrame.origin.y += deltaY
        let clamped = clampedToVisibleFrame(nextFrame)
        if !frame.equalTo(clamped) {
            setFrame(clamped, display: true)
            onFrameChanged?()
        }
    }

    private func endMove() {
        moveAnchorMouseLocation = nil
        moveAnchorFrame = nil
        onMoveStateChanged?(false)
        onFrameChanged?()
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

    func applySizePreset(_ preset: CameraBubbleSizePreset) {
        let targetSize = preset.sideLength
        let center = NSPoint(x: frame.midX, y: frame.midY)
        var nextFrame = NSRect(
            x: center.x - targetSize / 2,
            y: center.y - targetSize / 2,
            width: targetSize,
            height: targetSize
        )
        nextFrame = clampedToVisibleFrame(nextFrame)
        if !frame.equalTo(nextFrame) {
            setFrame(nextFrame, display: true, animate: false)
            onFrameChanged?()
        }
    }

    func currentSizePreset() -> CameraBubbleSizePreset {
        let side = frame.width
        return CameraBubbleSizePreset.allCases.min {
            abs($0.sideLength - side) < abs($1.sideLength - side)
        } ?? .medium
    }
}
