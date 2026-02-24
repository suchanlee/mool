import AppKit
import AVFoundation
import SwiftUI

// MARK: - Camera Bubble View

/// Circular camera preview with drag support and a corner resize handle.
struct CameraBubbleView: View {
    let cameraManager: any CameraManaging
    let onMoveBy: (_ deltaX: CGFloat, _ deltaY: CGFloat) -> Void
    let onResizeBy: (_ delta: CGFloat) -> Void

    @State private var isDraggingResize = false
    @State private var lastMoveTranslation: CGSize = .zero
    @State private var lastResizeTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Camera preview (circular)
            CameraPreviewRepresentable(previewLayer: cameraManager.previewLayer)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            // Resize handle (bottom-right corner)
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.7))
                .padding(5)
                .background(.black.opacity(0.4), in: Circle())
                .padding(4)
                .gesture(resizeGesture)
        }
        .contentShape(Circle())
        .simultaneousGesture(moveGesture)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !isDraggingResize else { return }
                let stepX = value.translation.width - lastMoveTranslation.width
                let stepY = value.translation.height - lastMoveTranslation.height
                lastMoveTranslation = value.translation
                onMoveBy(stepX, stepY)
            }
            .onEnded { _ in
                lastMoveTranslation = .zero
            }
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                isDraggingResize = true
                let stepX = value.translation.width - lastResizeTranslation.width
                let stepY = value.translation.height - lastResizeTranslation.height
                lastResizeTranslation = value.translation
                let delta = (stepX + stepY) / 2
                onResizeBy(delta)
            }
            .onEnded { _ in
                isDraggingResize = false
                lastResizeTranslation = .zero
            }
    }
}

// MARK: - Camera Preview (AVCaptureVideoPreviewLayer → NSViewRepresentable)

struct CameraPreviewRepresentable: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}
