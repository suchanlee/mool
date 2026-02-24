import AppKit
import AVFoundation
import SwiftUI

// MARK: - Camera Bubble View

/// Circular camera preview with drag support.
struct CameraBubbleView: View {
    let cameraManager: any CameraManaging
    let onMoveBegan: (_ mouseLocationInScreen: NSPoint) -> Void
    let onMoveChanged: (_ mouseLocationInScreen: NSPoint) -> Void
    let onMoveEnded: () -> Void

    @State private var hasStartedMoveDrag = false

    var body: some View {
        CameraPreviewRepresentable(previewLayer: cameraManager.previewLayer)
            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
            .contentShape(Circle())
            .simultaneousGesture(moveGesture)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                let mouse = NSEvent.mouseLocation
                if !hasStartedMoveDrag {
                    hasStartedMoveDrag = true
                    onMoveBegan(mouse)
                }
                onMoveChanged(mouse)
            }
            .onEnded { _ in
                hasStartedMoveDrag = false
                onMoveEnded()
            }
    }
}

// MARK: - Camera Preview (AVCaptureVideoPreviewLayer → NSViewRepresentable)

struct CameraPreviewRepresentable: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.wantsLayer = true
        view.configure(previewLayer: previewLayer)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewContainerView, context: Context) {
        nsView.updateCircularLayout(previewLayer: previewLayer)
    }
}

final class CameraPreviewContainerView: NSView {
    private weak var installedPreviewLayer: AVCaptureVideoPreviewLayer?

    override var isOpaque: Bool {
        false
    }

    func configure(previewLayer: AVCaptureVideoPreviewLayer) {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = false

        if installedPreviewLayer !== previewLayer {
            installedPreviewLayer?.removeFromSuperlayer()
            installedPreviewLayer = previewLayer
            previewLayer.videoGravity = .resizeAspectFill
            layer?.addSublayer(previewLayer)
        }

        updateCircularLayout(previewLayer: previewLayer)
    }

    func updateCircularLayout(previewLayer: AVCaptureVideoPreviewLayer) {
        guard let layer else { return }

        let diameter = min(bounds.width, bounds.height)
        let circleFrame = CGRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        previewLayer.frame = circleFrame
        previewLayer.cornerRadius = diameter / 2
        previewLayer.masksToBounds = true

        layer.shadowColor = NSColor.black.cgColor
        layer.shadowOpacity = 0.22
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: -6)
        layer.shadowPath = CGPath(ellipseIn: circleFrame.insetBy(dx: 1.5, dy: 1.5), transform: nil)
    }
}
