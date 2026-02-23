import Foundation
import Combine

// MARK: - Recording State

enum RecordingState: Equatable {
    case idle
    case countdown(secondsRemaining: Int)
    case recording
    case paused
    case finishing
}

// MARK: - Recording Session

/// Represents a completed or in-progress recording.
struct RecordingSession: Identifiable, Hashable {
    let id: UUID
    let startDate: Date
    var duration: TimeInterval
    var fileURL: URL?
    var thumbnailURL: URL?
    var title: String

    init(startDate: Date = .now) {
        self.id = UUID()
        self.startDate = startDate
        self.duration = 0
        self.title = RecordingSession.defaultTitle(for: startDate)
    }

    static func defaultTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "Recording \(formatter.string(from: date))"
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
