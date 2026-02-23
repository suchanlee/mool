import AppKit
import Combine
import CoreGraphics
import SwiftUI

// MARK: - Annotation Tool

enum AnnotationTool: CaseIterable {
    case pen
    case eraser
    case highlighter

    var iconName: String {
        switch self {
        case .pen: "pencil"
        case .eraser: "eraser"
        case .highlighter: "highlighter"
        }
    }
}

// MARK: - Stroke

struct Stroke: Identifiable {
    let id: UUID = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    var isHighlighter: Bool

    init(start: CGPoint, color: Color, lineWidth: CGFloat, isHighlighter: Bool = false) {
        self.points = [start]
        self.color = color
        self.lineWidth = lineWidth
        self.isHighlighter = isHighlighter
    }
}

// MARK: - Annotation Manager

@Observable
@MainActor
final class AnnotationManager {

    // Drawing state
    var isAnnotating: Bool = false {
        didSet { overlayWindow?.ignoresMouseEvents = !isAnnotating }
    }
    var selectedTool: AnnotationTool = .pen
    var selectedColor: Color = .red
    var lineWidth: CGFloat = 3.0
    var strokes: [Stroke] = []

    // Cursor effects
    var showCursorHighlight: Bool = false
    var showCursorSpotlight: Bool = false
    var currentCursorPosition: CGPoint = .zero

    // Weak reference to overlay — set by WindowCoordinator
    weak var overlayWindow: NSWindow?

    private var activeStroke: Stroke?

    // MARK: - Drawing actions

    func beginStroke(at point: CGPoint) {
        let color: Color = selectedTool == .highlighter
            ? selectedColor.opacity(0.4)
            : selectedColor
        let width: CGFloat = selectedTool == .highlighter ? lineWidth * 3 : lineWidth
        activeStroke = Stroke(
            start: point,
            color: color,
            lineWidth: width,
            isHighlighter: selectedTool == .highlighter
        )
    }

    func continueStroke(at point: CGPoint) {
        activeStroke?.points.append(point)
        // Publish a copy so observers react
        if let s = activeStroke {
            // Replace the last stroke (which is the active one) or append
            if let idx = strokes.indices.last, strokes[idx].id == s.id {
                strokes[idx] = s
            } else {
                strokes.append(s)
            }
        }
    }

    func endStroke() {
        activeStroke = nil
    }

    func eraseNear(_ point: CGPoint, radius: CGFloat = 20) {
        strokes.removeAll { stroke in
            stroke.points.contains { $0.distance(to: point) < radius }
        }
    }

    func clearAll() {
        strokes = []
        activeStroke = nil
    }

    func undoLast() {
        guard !strokes.isEmpty else { return }
        strokes.removeLast()
    }
}

// MARK: - CGPoint helper

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}
