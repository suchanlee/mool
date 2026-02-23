import AppKit
import SwiftUI

// MARK: - Speaker Notes Window

/// A floating panel for speaker notes during recording.
final class SpeakerNotesWindow: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.nonactivatingPanel, .titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "Speaker Notes"
        titlebarAppearsTransparent = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9)
        hasShadow = true
        isReleasedWhenClosed = false

        contentView = NSHostingView(rootView: SpeakerNotesView())

        // Position: top-left of main screen
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.minX + 20
            let y = screen.visibleFrame.maxY - frame.height - 20
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

// MARK: - Speaker Notes View

struct SpeakerNotesView: View {
    @AppStorage("mool.speakerNotes") private var notes: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Speaker Notes")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            TextEditor(text: $notes)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(8)
        }
        .background(.ultraThinMaterial)
    }
}
