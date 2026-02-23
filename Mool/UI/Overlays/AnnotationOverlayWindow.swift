import AppKit
import SwiftUI

// MARK: - Annotation Overlay Window

/// A full-screen transparent window for drawing annotations.
/// Passes through mouse events when annotation mode is off.
final class AnnotationOverlayWindow: NSWindow {

    init(screen: NSScreen, annotationManager: AnnotationManager, cursorTracker: CursorTracker) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true   // pass-through by default
        isReleasedWhenClosed = false

        let view = AnnotationOverlayView(
            annotationManager: annotationManager,
            cursorTracker: cursorTracker
        )
        contentView = NSHostingView(rootView: view)
    }
}

// MARK: - Annotation Overlay View

/// Full-screen SwiftUI canvas for drawing strokes + cursor effects.
struct AnnotationOverlayView: View {
    @Bindable var annotationManager: AnnotationManager
    let cursorTracker: CursorTracker

    // Local state for cursor effects
    @State private var cursorPos: CGPoint = .zero
    @State private var clickBursts: [ClickBurst] = []

    var body: some View {
        ZStack {
            // Spotlight overlay (dim everything except around cursor)
            if annotationManager.showCursorSpotlight {
                SpotlightOverlay(center: cursorPos)
            }

            // Strokes canvas
            Canvas { context, size in
                for stroke in annotationManager.strokes {
                    guard stroke.points.count >= 2 else { continue }
                    var path = Path()
                    path.move(to: stroke.points[0])
                    for pt in stroke.points.dropFirst() {
                        path.addLine(to: pt)
                    }
                    context.stroke(
                        path,
                        with: .color(stroke.color),
                        style: StrokeStyle(
                            lineWidth: stroke.lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }

            // Cursor highlight ring
            if annotationManager.showCursorHighlight {
                Circle()
                    .strokeBorder(.yellow.opacity(0.8), lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .position(cursorPos)
                    .allowsHitTesting(false)
            }

            // Click burst animations
            ForEach(clickBursts) { burst in
                ClickBurstView(burst: burst)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        // Drawing gestures (only captured when annotating)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if annotationManager.selectedTool == .eraser {
                        annotationManager.eraseNear(value.location)
                    } else {
                        if value.translation == .zero {
                            annotationManager.beginStroke(at: value.location)
                        } else {
                            annotationManager.continueStroke(at: value.location)
                        }
                    }
                }
                .onEnded { _ in annotationManager.endStroke() }
        )
        .onReceive(cursorTracker.eventPublisher) { event in
            cursorPos = event.position
            if event.isClick {
                let burst = ClickBurst(position: event.position)
                clickBursts.append(burst)
                // Remove after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    clickBursts.removeAll { $0.id == burst.id }
                }
            }
        }
    }
}

// MARK: - Spotlight Overlay

struct SpotlightOverlay: View {
    let center: CGPoint
    let radius: CGFloat = 120

    var body: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Fill entire area with dim
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
                // Cut out spotlight
                ctx.blendMode = .destinationOut
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )),
                    with: .color(.black)
                )
            }
            .compositingGroup()
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Click Burst

struct ClickBurst: Identifiable {
    let id = UUID()
    let position: CGPoint
}

struct ClickBurstView: View {
    let burst: ClickBurst
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .strokeBorder(.yellow, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(burst.position)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) {
                    scale = 1.5
                    opacity = 0
                }
            }
            .allowsHitTesting(false)
    }
}
