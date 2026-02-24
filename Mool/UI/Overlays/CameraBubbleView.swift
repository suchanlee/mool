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
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.24), radius: 14, y: 8)
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
