import AppKit
import AVFoundation
import SwiftUI

// MARK: - Camera Bubble View

/// Circular camera preview with drag support and a corner resize handle.
struct CameraBubbleView: View {
    let cameraManager: any CameraManaging
    let onMoveBegan: (_ mouseLocationInScreen: NSPoint) -> Void
    let onMoveChanged: (_ mouseLocationInScreen: NSPoint) -> Void
    let onMoveEnded: () -> Void
    let onResizeBegan: (_ mouseLocationInScreen: NSPoint) -> Void
    let onResizeChanged: (_ mouseLocationInScreen: NSPoint) -> Void
    let onResizeEnded: () -> Void

    @State private var isDraggingResize = false
    @State private var hasStartedMoveDrag = false
    @State private var hasStartedResizeDrag = false

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
            .onChanged { _ in
                guard !isDraggingResize else { return }
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

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                isDraggingResize = true
                let mouse = NSEvent.mouseLocation
                if !hasStartedResizeDrag {
                    hasStartedResizeDrag = true
                    onResizeBegan(mouse)
                }
                onResizeChanged(mouse)
            }
            .onEnded { _ in
                isDraggingResize = false
                hasStartedResizeDrag = false
                onResizeEnded()
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
