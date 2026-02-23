import AVFoundation
import AppKit
import SwiftUI

// MARK: - Camera Bubble View

/// Circular camera preview with drag support and a corner resize handle.
struct CameraBubbleView: View {
    let cameraManager: any CameraManaging

    @State private var size: CGFloat = 200
    @State private var isDraggingResize = false

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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let delta = (value.translation.width + value.translation.height) / 2
                            size = max(100, min(400, size + delta))
                        }
                )
        }
        .frame(width: size, height: size)
        .animation(.interactiveSpring(), value: size)
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
