import Foundation
import ScreenCaptureKit

// MARK: - Capture Source

/// Represents what can be captured: an entire display or a specific window.
enum CaptureSource: Identifiable, Hashable {
    case display(SCDisplay)
    case window(SCWindow)

    var id: String {
        switch self {
        case .display(let d): "display-\(d.displayID)"
        case .window(let w): "window-\(w.windowID)"
        }
    }

    var displayName: String {
        switch self {
        case .display(let d): "Display \(d.displayID) (\(Int(d.width))×\(Int(d.height)))"
        case .window(let w): w.title ?? w.owningApplication?.applicationName ?? "Unknown Window"
        }
    }

    var appName: String? {
        switch self {
        case .display: nil
        case .window(let w): w.owningApplication?.applicationName
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CaptureSource, rhs: CaptureSource) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Available Sources

@Observable
@MainActor
final class AvailableSources {
    var displays: [SCDisplay] = []
    var windows: [SCWindow] = []
    var isLoading: Bool = false

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            displays = content.displays
            windows = content.windows.filter { $0.title != nil && $0.frame.width > 100 }
        } catch {
            print("[AvailableSources] Failed to enumerate sources: \(error)")
        }
    }
}
