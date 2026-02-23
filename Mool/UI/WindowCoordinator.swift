import AppKit

// MARK: - Window Coordinator

/// Owns and manages all overlay windows (control panel, camera bubble,
/// annotation overlay, speaker notes). Shown/hidden around recording sessions.
@MainActor
final class WindowCoordinator {

    private unowned let recordingEngine: RecordingEngine

    let annotationManager = AnnotationManager()
    private let cursorTracker = CursorTracker()

    private var controlPanelWindow: ControlPanelWindow?
    private var cameraBubbleWindow: CameraBubbleWindow?
    private var annotationOverlayWindow: AnnotationOverlayWindow?
    private var speakerNotesWindow: SpeakerNotesWindow?
    private var sourcePickerController: SourcePickerController?

    // MARK: - Init

    init(recordingEngine: RecordingEngine) {
        self.recordingEngine = recordingEngine
        buildWindows()
        setupGlobalShortcuts()
    }

    // MARK: - Build

    private func buildWindows() {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        controlPanelWindow = ControlPanelWindow(
            recordingEngine: recordingEngine,
            annotationManager: annotationManager
        )

        cameraBubbleWindow = CameraBubbleWindow(
            cameraManager: recordingEngine.cameraManager
        )

        let overlayWin = AnnotationOverlayWindow(
            screen: screen,
            annotationManager: annotationManager,
            cursorTracker: cursorTracker
        )
        annotationManager.overlayWindow = overlayWin
        annotationOverlayWindow = overlayWin

        speakerNotesWindow = SpeakerNotesWindow()
        sourcePickerController = SourcePickerController(engine: recordingEngine, coordinator: self)
    }

    // MARK: - Source Picker

    func showSourcePicker() {
        sourcePickerController?.show()
    }

    // MARK: - Show / Hide

    func showOverlays() {
        controlPanelWindow?.orderFront(nil)

        if recordingEngine.settings.mode.includesCamera {
            cameraBubbleWindow?.orderFront(nil)
        }

        annotationOverlayWindow?.orderFront(nil)
        cursorTracker.startTracking()
    }

    func hideOverlays() {
        controlPanelWindow?.orderOut(nil)
        cameraBubbleWindow?.orderOut(nil)
        annotationOverlayWindow?.orderOut(nil)
        speakerNotesWindow?.orderOut(nil)
        annotationManager.isAnnotating = false
        cursorTracker.stopTracking()
    }

    func toggleSpeakerNotes() {
        guard let notes = speakerNotesWindow else { return }
        if notes.isVisible {
            notes.orderOut(nil)
        } else {
            notes.orderFront(nil)
        }
    }

    func toggleCameraBubble() {
        guard let cam = cameraBubbleWindow else { return }
        if cam.isVisible {
            cam.orderOut(nil)
        } else {
            cam.orderFront(nil)
        }
    }

    // MARK: - Global Keyboard Shortcuts

    private func setupGlobalShortcuts() {
        let settings = recordingEngine.settings

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.handleGlobalKeyEvent(event)
            }
        }
        _ = settings  // reference to trigger observation in future
    }

    private func handleGlobalKeyEvent(_ event: NSEvent) {
        let shortcuts = recordingEngine.settings.shortcuts
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        func matches(_ shortcut: RecordingShortcut) -> Bool {
            event.charactersIgnoringModifiers?.lowercased() == shortcut.key &&
            flags == shortcut.modifiers.toNSEventModifiers()
        }

        if matches(shortcuts.startStop) {
            if recordingEngine.state == .idle {
                showSourcePicker()
            } else {
                Task { await recordingEngine.stopRecording(); hideOverlays() }
            }
        } else if matches(shortcuts.pauseResume) {
            if recordingEngine.state == .recording {
                recordingEngine.pauseRecording()
            } else if recordingEngine.state == .paused {
                recordingEngine.resumeRecording()
            }
        } else if matches(shortcuts.toggleAnnotation) {
            annotationManager.isAnnotating.toggle()
        } else if matches(shortcuts.toggleCamera) {
            toggleCameraBubble()
        } else if matches(shortcuts.toggleSpeakerNotes) {
            toggleSpeakerNotes()
        }
    }
}
