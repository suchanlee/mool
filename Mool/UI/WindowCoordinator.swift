import AppKit

enum CountdownTargetResolver {
    struct DisplaySource: Equatable {
        let displayID: CGDirectDisplayID
    }

    struct WindowSource: Equatable {
        let windowID: CGWindowID
        let frame: CGRect
    }

    struct ScreenTarget: Equatable {
        let displayID: CGDirectDisplayID
        let frame: CGRect
    }

    static func resolveDisplayIDs(
        modeIncludesScreen: Bool,
        selectedDisplayIndex: Int,
        selectedWindowID: CGWindowID?,
        availableDisplays: [DisplaySource],
        availableWindows: [WindowSource],
        connectedScreens: [ScreenTarget]
    ) -> [CGDirectDisplayID] {
        guard modeIncludesScreen else { return [] }
        guard !connectedScreens.isEmpty else { return [] }

        if let selectedWindowID,
           let window = availableWindows.first(where: { $0.windowID == selectedWindowID }),
           let screen = connectedScreens
           .map({ ($0.displayID, overlapArea(lhs: $0.frame, rhs: window.frame)) })
           .max(by: { $0.1 < $1.1 }),
           screen.1 > 0
        {
            return [screen.0]
        }

        guard !availableDisplays.isEmpty else {
            return [connectedScreens[0].displayID]
        }

        let index = min(max(selectedDisplayIndex, 0), availableDisplays.count - 1)
        let displayID = availableDisplays[index].displayID
        if connectedScreens.contains(where: { $0.displayID == displayID }) {
            return [displayID]
        }

        return [connectedScreens[0].displayID]
    }

    private static func overlapArea(lhs: CGRect, rhs: CGRect) -> CGFloat {
        lhs.intersection(rhs).isNull ? 0 : lhs.intersection(rhs).width * lhs.intersection(rhs).height
    }
}

// MARK: - Window Coordinator

/// Owns and manages all overlay windows (control panel, camera bubble,
/// annotation overlay, speaker notes). Shown/hidden around recording sessions.
@MainActor
final class WindowCoordinator {
    private unowned let recordingEngine: RecordingEngine
    private unowned let permissionManager: PermissionManager

    let annotationManager = AnnotationManager()
    private let cursorTracker = CursorTracker()

    private var controlPanelWindow: ControlPanelWindow?
    private var cameraBubbleWindow: CameraBubbleWindow?
    private var annotationOverlayWindow: AnnotationOverlayWindow?
    private var speakerNotesWindow: SpeakerNotesWindow?
    private var countdownOverlayWindows: [CountdownOverlayWindow] = []
    private var sourcePickerController: SourcePickerController?
    private var recordingStateObserver: NSObjectProtocol?
    private var localHUDHoverMonitor: Any?
    private var globalHUDHoverMonitor: Any?
    private var showsQuickPreviewBubble = false
    private var isDraggingCameraBubble = false

    // MARK: - Init

    init(recordingEngine: RecordingEngine, permissionManager: PermissionManager) {
        self.recordingEngine = recordingEngine
        self.permissionManager = permissionManager
        buildWindows()
        startRecordingStateObservation()
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
        sourcePickerController = SourcePickerController(
            engine: recordingEngine,
            coordinator: self,
            permissionManager: permissionManager
        )
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
        configureHUDHoverMonitoring()
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
        stopHUDHoverMonitoring()
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
        configureHUDHoverMonitoring()
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
            configureHUDHoverMonitoring()
        }
    }

    private func startRecordingStateObservation() {
        stopRecordingStateObservation()
        recordingStateObserver = NotificationCenter.default.addObserver(
            forName: .recordingEngineStateDidChange,
            object: recordingEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleRecordingStateChange()
            }
        }
        handleRecordingStateChange()
    }

    private func stopRecordingStateObservation() {
        if let observer = recordingStateObserver {
            NotificationCenter.default.removeObserver(observer)
            recordingStateObserver = nil
        }
    }

    private func handleRecordingStateChange() {
        let state = recordingEngine.state

        if state == .idle {
            hideOverlays()
        }
        refreshQuickPreviewBubble()
        updateBubbleAttachedHUD()
        configureHUDHoverMonitoring()

        switch state {
        case let .countdown(seconds):
            showCountdownOverlay(secondsRemaining: seconds)
        default:
            hideCountdownOverlay()
        }
    }

    private func configureHUDHoverMonitoring() {
        let state = recordingEngine.state
        let shouldMonitor = (state == .recording || state == .paused) &&
            recordingEngine.settings.mode.includesCamera &&
            !isDraggingCameraBubble
        if shouldMonitor {
            startHUDHoverMonitoring()
        } else {
            stopHUDHoverMonitoring()
        }
    }

    private func startHUDHoverMonitoring() {
        guard localHUDHoverMonitor == nil, globalHUDHoverMonitor == nil else { return }

        let events: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .leftMouseDown,
            .rightMouseDown
        ]

        localHUDHoverMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            self?.updateBubbleAttachedHUD()
            return event
        }

        globalHUDHoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            Task { @MainActor in
                self?.updateBubbleAttachedHUD()
            }
        }
    }

    private func stopHUDHoverMonitoring() {
        if let monitor = localHUDHoverMonitor {
            NSEvent.removeMonitor(monitor)
            localHUDHoverMonitor = nil
        }
        if let monitor = globalHUDHoverMonitor {
            NSEvent.removeMonitor(monitor)
            globalHUDHoverMonitor = nil
        }
    }

    private func showCountdownOverlay(secondsRemaining: Int) {
        let screens = countdownTargetScreens()
        guard !screens.isEmpty else {
            hideCountdownOverlay()
            return
        }

        let currentDisplayIDs = countdownOverlayWindows.map(\.displayID)
        let targetDisplayIDs = screens.map(\.displayID)

        if currentDisplayIDs != targetDisplayIDs {
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

    private func countdownTargetScreens() -> [NSScreen] {
        let targetDisplayIDs = CountdownTargetResolver.resolveDisplayIDs(
            modeIncludesScreen: recordingEngine.settings.mode.includesScreen,
            selectedDisplayIndex: recordingEngine.settings.selectedDisplayIndex,
            selectedWindowID: recordingEngine.settings.selectedWindowID,
            availableDisplays: recordingEngine.availableSources.displays.map {
                CountdownTargetResolver.DisplaySource(displayID: $0.displayID)
            },
            availableWindows: recordingEngine.availableSources.windows.map {
                CountdownTargetResolver.WindowSource(windowID: $0.windowID, frame: $0.frame)
            },
            connectedScreens: NSScreen.screens.compactMap { screen in
                guard let displayID = screen.displayID else { return nil }
                return CountdownTargetResolver.ScreenTarget(displayID: displayID, frame: screen.frame)
            }
        )

        return targetDisplayIDs.compactMap { targetDisplayID in
            NSScreen.screens.first(where: { $0.displayID == targetDisplayID })
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

private extension NSScreen {
    var displayID: CGDirectDisplayID? {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
}
