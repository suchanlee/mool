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
    var onFrameChanged: (() -> Void)?
    var onMoveStateChanged: ((Bool) -> Void)?
    private var isDraggingWindow = false

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

        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false

        let view = CameraBubbleView(
            cameraManager: cameraManager
        )
        contentView = BubbleHostingView(rootView: view)

        // Default position: bottom-right corner of main screen
        if let screen = NSScreen.main {
            let margin: CGFloat = 24
            let x = screen.visibleFrame.maxX - defaultSize - margin
            let y = screen.visibleFrame.minY + margin
            setFrameOrigin(NSPoint(x: x, y: y))
        }
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
        nextFrame = constrainFrameRect(nextFrame, to: screen)
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

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if !isDraggingWindow {
                isDraggingWindow = true
                onMoveStateChanged?(true)
            }
        case .leftMouseUp:
            if isDraggingWindow {
                isDraggingWindow = false
                onMoveStateChanged?(false)
            }
        default:
            break
        }

        super.sendEvent(event)
    }

    override func setFrameOrigin(_ point: NSPoint) {
        let previousFrame = frame
        super.setFrameOrigin(point)
        if !frame.equalTo(previousFrame) {
            onFrameChanged?()
        }
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? frameRect
        var constrained = frameRect
        constrained.origin.x = min(max(constrained.origin.x, visibleFrame.minX), visibleFrame.maxX - constrained.width)
        constrained.origin.y = min(max(constrained.origin.y, visibleFrame.minY), visibleFrame.maxY - constrained.height)
        return constrained
    }
}

private final class BubbleHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        true
    }
}
