import CoreGraphics
import Foundation
import ScreenCaptureKit

// MARK: - Capture Source

/// Represents what can be captured: an entire display or a specific window.
enum CaptureSource: Identifiable, Hashable {
    case display(SCDisplay)
    case window(SCWindow)

    var id: String {
        switch self {
        case let .display(d): "display-\(d.displayID)"
        case let .window(w): "window-\(w.windowID)"
        }
    }

    var displayName: String {
        switch self {
        case let .display(d): "Display \(d.displayID) (\(Int(d.width))×\(Int(d.height)))"
        case let .window(w): w.title ?? w.owningApplication?.applicationName ?? "Unknown Window"
        }
    }

    var appName: String? {
        switch self {
        case .display: nil
        case let .window(w): w.owningApplication?.applicationName
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

        guard CGPreflightScreenCaptureAccess() else {
            displays = []
            windows = []
            return
        }

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
