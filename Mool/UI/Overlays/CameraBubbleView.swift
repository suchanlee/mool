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
        ZStack {
            // Explicit circular shadow avoids rectangular NSView shadow artifacts.
            Circle()
                .fill(Color.black.opacity(0.22))
                .blur(radius: 16)
                .offset(y: 8)
                .padding(10)

            CameraPreviewRepresentable(previewLayer: cameraManager.previewLayer)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1.5))
        }
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
        view.layer?.backgroundColor = NSColor.clear.cgColor
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewContainerView, context: Context) {
        previewLayer.frame = nsView.bounds
        nsView.layer?.masksToBounds = true
        nsView.layer?.cornerRadius = min(nsView.bounds.width, nsView.bounds.height) / 2
    }
}

final class CameraPreviewContainerView: NSView {
    override var isOpaque: Bool {
        false
    }
}
