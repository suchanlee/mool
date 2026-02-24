import AppKit
import SwiftUI

// MARK: - Source Picker Controller

/// Presents the source picker as a floating window.
/// On confirm: starts recording and shows overlays.
/// On cancel: just closes.
@MainActor
final class SourcePickerController {
    private var window: NSWindow?
    private unowned let engine: RecordingEngine
    private unowned let coordinator: WindowCoordinator

    init(engine: RecordingEngine, coordinator: WindowCoordinator) {
        self.engine = engine
        self.coordinator = coordinator
    }

    func show() {
        // If already showing, just bring to front
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = "New Recording"
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.isReleasedWhenClosed = false
        win.center()

        let view = SourcePickerView(
            engine: engine,
            onStartRecording: { [weak self] in
                self?.startRecording()
            },
            onCancel: { [weak self] in
                self?.dismiss()
            }
        )
        win.contentView = NSHostingView(rootView: view)
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = win
    }

    private func startRecording() {
        dismiss()
        Task {
            do {
                try await engine.startRecording()
                coordinator.showOverlays()
            } catch {
                coordinator.hideOverlays()
                engine.teardownQuickRecorderContext()
                showError(error)
            }
        }
    }

    private func dismiss() {
        window?.orderOut(nil)
        window = nil
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Recording Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.runModal()
    }
}
