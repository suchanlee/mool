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
    private var countdownOverlayWindows: [CountdownOverlayWindow] = []
    private var sourcePickerController: SourcePickerController?
    private var stateObserverTimer: Timer?
    private var lastObservedState: RecordingState = .idle
    private var showsQuickPreviewBubble = false
    private var isDraggingCameraBubble = false

    // MARK: - Init

    init(recordingEngine: RecordingEngine) {
        self.recordingEngine = recordingEngine
        buildWindows()
        startStateObservation()
    }

    // MARK: - Build

    private func buildWindows() {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        controlPanelWindow = ControlPanelWindow(
            recordingEngine: recordingEngine,
            annotationManager: annotationManager,
            onStopRequested: { [weak self] in
                self?.hideOverlays()
            },
            onBubbleSizeSelected: { [weak self] preset in
                self?.setCameraBubbleSize(preset)
            },
            currentBubbleSize: { [weak self] in
                self?.cameraBubbleWindow?.currentSizePreset()
            }
        )

        cameraBubbleWindow = CameraBubbleWindow(
            cameraManager: recordingEngine.cameraManager
        )
        cameraBubbleWindow?.onFrameChanged = { [weak self] in
            self?.updateBubbleAttachedHUD()
        }
        cameraBubbleWindow?.onMoveStateChanged = { [weak self] isMoving in
            guard let self else { return }
            isDraggingCameraBubble = isMoving
            updateBubbleAttachedHUD()
        }

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
        // Keep the annotation canvas behind interactive HUD windows.
        annotationOverlayWindow?.orderFront(nil)

        if recordingEngine.settings.mode.includesCamera {
            cameraBubbleWindow?.orderFront(nil)
            updateBubbleAttachedHUD()
        } else {
            positionControlPanelBottomCenter()
            controlPanelWindow?.orderFront(nil)
        }

        cursorTracker.startTracking()
    }

    func hideOverlays() {
        controlPanelWindow?.orderOut(nil)
        if !showsQuickPreviewBubble {
            cameraBubbleWindow?.orderOut(nil)
        }
        annotationOverlayWindow?.orderOut(nil)
        speakerNotesWindow?.orderOut(nil)
        hideCountdownOverlay()
        annotationManager.isAnnotating = false
        cursorTracker.stopTracking()
    }

    func showQuickPreviewBubble() {
        showsQuickPreviewBubble = true
        refreshQuickPreviewBubble()
    }

    func refreshQuickPreviewBubble() {
        guard showsQuickPreviewBubble else { return }
        guard recordingEngine.state == .idle else { return }
        controlPanelWindow?.orderOut(nil)

        if recordingEngine.settings.mode.includesCamera {
            recordingEngine.ensureIdlePreviewState()
            cameraBubbleWindow?.orderFront(nil)
        } else {
            cameraBubbleWindow?.orderOut(nil)
        }
    }

    func hideQuickPreviewBubble() {
        showsQuickPreviewBubble = false
        if recordingEngine.state == .idle {
            cameraBubbleWindow?.orderOut(nil)
        }
    }

    func isPointInVisibleCameraBubble(_ screenPoint: NSPoint) -> Bool {
        guard let bubble = cameraBubbleWindow, bubble.isVisible else { return false }
        return bubble.frame.contains(screenPoint)
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

        if recordingEngine.state == .recording || recordingEngine.state == .paused {
            updateBubbleAttachedHUD()
        }
    }

    private func startStateObservation() {
        stateObserverTimer?.invalidate()
        stateObserverTimer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(handleStateObservationTick),
            userInfo: nil,
            repeats: true
        )
    }

    @objc private func handleStateObservationTick() {
        let state = recordingEngine.state

        if state == .idle, lastObservedState != .idle {
            hideOverlays()
        }
        lastObservedState = state

        refreshQuickPreviewBubble()
        updateBubbleAttachedHUD()

        switch state {
        case let .countdown(seconds):
            showCountdownOverlay(secondsRemaining: seconds)
        default:
            hideCountdownOverlay()
        }
    }

    private func showCountdownOverlay(secondsRemaining: Int) {
        let screens = NSScreen.screens

        if countdownOverlayWindows.count != screens.count {
            countdownOverlayWindows.forEach { $0.orderOut(nil) }
            countdownOverlayWindows = screens.map { CountdownOverlayWindow(screen: $0, secondsRemaining: secondsRemaining) }
        }

        for overlay in countdownOverlayWindows {
            overlay.update(secondsRemaining: secondsRemaining)
            if !overlay.isVisible {
                overlay.orderFrontRegardless()
            }
        }
    }

    private func hideCountdownOverlay() {
        for overlay in countdownOverlayWindows where overlay.isVisible {
            overlay.orderOut(nil)
        }
    }

    private func updateBubbleAttachedHUD() {
        guard let controlPanel = controlPanelWindow else { return }

        let state = recordingEngine.state
        let isRecordingState = state == .recording || state == .paused
        let isCameraMode = recordingEngine.settings.mode.includesCamera
        let shouldAttachToBubble = isRecordingState && isCameraMode

        guard shouldAttachToBubble else {
            if isRecordingState {
                positionControlPanelBottomCenter()
                controlPanel.orderFront(nil)
            } else {
                controlPanel.orderOut(nil)
            }
            return
        }

        guard let bubble = cameraBubbleWindow else {
            positionControlPanelBottomCenter()
            controlPanel.orderFront(nil)
            return
        }

        if bubble.isVisible {
            positionControlPanelBelowBubble()

            // During active bubble drag, hide HUD to avoid detached/lagging visuals.
            if isDraggingCameraBubble {
                if controlPanel.isVisible {
                    controlPanel.orderOut(nil)
                }
                return
            }

            let mouse = NSEvent.mouseLocation
            let shouldShowHUD = bubble.frame.contains(mouse) || controlPanel.frame.contains(mouse)

            if shouldShowHUD {
                if !controlPanel.isVisible {
                    controlPanel.orderFront(nil)
                }
            } else {
                if controlPanel.isVisible {
                    controlPanel.orderOut(nil)
                }
            }
        } else {
            positionControlPanelBottomCenter()
            controlPanel.orderFront(nil)
        }
    }

    private func positionControlPanelBelowBubble() {
        guard let controlPanel = controlPanelWindow, let bubble = cameraBubbleWindow else { return }
        let panelSize = controlPanel.frame.size

        let visible = bubble.screen?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? .zero
        guard !visible.equalTo(.zero) else { return }

        let edgePadding: CGFloat = 12
        let overlap: CGFloat = 14
        var x = bubble.frame.midX - panelSize.width / 2
        x = min(max(x, visible.minX + edgePadding), visible.maxX - panelSize.width - edgePadding)

        var y = bubble.frame.minY - panelSize.height + overlap
        if y < visible.minY + edgePadding {
            y = bubble.frame.maxY - overlap
            y = min(y, visible.maxY - panelSize.height - edgePadding)
        }

        controlPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionControlPanelBottomCenter() {
        guard let controlPanel = controlPanelWindow else { return }
        let visible = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        guard !visible.equalTo(.zero) else { return }

        let x = visible.midX - controlPanel.frame.width / 2
        let y = visible.minY + 40
        controlPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func setCameraBubbleSize(_ preset: CameraBubbleSizePreset) {
        cameraBubbleWindow?.applySizePreset(preset)
        updateBubbleAttachedHUD()
    }
}
