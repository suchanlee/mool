import AppKit
import SwiftUI

// MARK: - Menu Bar Controller

/// Manages the NSStatusItem (menu bar icon) and associated menu/popover.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var statusBarMenu: NSMenu?
    private let quickRecorderPopover = NSPopover()
    private var quickPreviewTask: Task<Void, Never>?
    private var engineStateObserver: NSObjectProtocol?
    private var engineRuntimeErrorObserver: NSObjectProtocol?
    private var engineCompletedObserver: NSObjectProtocol?
    private var localPopoverClickMonitor: Any?
    private var globalPopoverClickMonitor: Any?
    private var localPopoverKeyMonitor: Any?
    private let menuActionTracePath = ProcessInfo.processInfo.environment["MOOL_STATUS_MENU_TRACE_PATH"]
    private let suppressRecordingErrorAlerts = ProcessInfo.processInfo.environment["MOOL_SUPPRESS_RECORDING_ERROR_ALERTS"] == "1"

    private unowned let recordingEngine: RecordingEngine
    private unowned let windowCoordinator: WindowCoordinator
    private unowned let permissionManager: PermissionManager
    private let openLibraryWindow: @MainActor () -> Void
    private let openSettingsWindow: @MainActor () -> Void

    // MARK: - Init

    init(
        recordingEngine: RecordingEngine,
        windowCoordinator: WindowCoordinator,
        permissionManager: PermissionManager,
        openLibraryWindow: @escaping @MainActor () -> Void,
        openSettingsWindow: @escaping @MainActor () -> Void
    ) {
        self.recordingEngine = recordingEngine
        self.windowCoordinator = windowCoordinator
        self.permissionManager = permissionManager
        self.openLibraryWindow = openLibraryWindow
        self.openSettingsWindow = openSettingsWindow
        super.init()
        setupStatusItem()
        observeRecordingEngine()
        updateMenuState()
        updateStatusIcon()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Mool")
            button.image?.isTemplate = true
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Keep popover open while interacting with the floating camera bubble.
        quickRecorderPopover.behavior = .applicationDefined
        quickRecorderPopover.animates = true
        quickRecorderPopover.delegate = self
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        let startItem = menu.addItem(withTitle: "Start Recording", action: #selector(startRecordingMenuAction(_:)), keyEquivalent: "")
        startItem.target = self
        startItem.identifier = NSUserInterfaceItemIdentifier("status.startRecording")

        let stopItem = menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecordingMenuAction(_:)), keyEquivalent: "")
        stopItem.target = self
        stopItem.identifier = NSUserInterfaceItemIdentifier("status.stopRecording")

        menu.addItem(.separator())

        let libraryItem = menu.addItem(withTitle: "Open Library", action: #selector(openLibraryMenuAction(_:)), keyEquivalent: "")
        libraryItem.target = self
        libraryItem.identifier = NSUserInterfaceItemIdentifier("status.openLibrary")

        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(openSettingsMenuAction(_:)), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.identifier = NSUserInterfaceItemIdentifier("status.openSettings")

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "Quit Mool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.identifier = NSUserInterfaceItemIdentifier("status.quit")

        statusBarMenu = menu
    }

    // MARK: - Recording Engine Observation

    private func observeRecordingEngine() {
        stopObservingRecordingEngine()

        let center = NotificationCenter.default
        engineStateObserver = center.addObserver(
            forName: .recordingEngineStateDidChange,
            object: recordingEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.updateMenuState()
                self.updateStatusIcon()
            }
        }

        engineRuntimeErrorObserver = center.addObserver(
            forName: .recordingEngineRuntimeErrorDidOccur,
            object: recordingEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showPendingRuntimeErrorIfNeeded()
            }
        }

        engineCompletedObserver = center.addObserver(
            forName: .recordingEngineDidCompleteRecording,
            object: recordingEngine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openLibraryForCompletedRecordingIfNeeded()
            }
        }
    }

    private func stopObservingRecordingEngine() {
        if let observer = engineStateObserver {
            NotificationCenter.default.removeObserver(observer)
            engineStateObserver = nil
        }
        if let observer = engineRuntimeErrorObserver {
            NotificationCenter.default.removeObserver(observer)
            engineRuntimeErrorObserver = nil
        }
        if let observer = engineCompletedObserver {
            NotificationCenter.default.removeObserver(observer)
            engineCompletedObserver = nil
        }
    }

    private func updateMenuState() {
        guard let menu = statusBarMenu else { return }
        let isIdle = recordingEngine.state == .idle
        let isRecording = recordingEngine.state == .recording

        menu.items.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("status.startRecording") })?.isEnabled = isIdle
        menu.items.first(where: { $0.identifier == NSUserInterfaceItemIdentifier("status.stopRecording") })?.isEnabled =
            isRecording || recordingEngine.state == .paused
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        switch recordingEngine.state {
        case .recording:
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = false
            if let img = button.image {
                button.image = img.tinted(with: .systemRed)
            }
        default:
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: "Mool")
            button.image?.isTemplate = true
        }
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            traceMenuAction("statusBarButtonClicked event=nil -> quickPopover")
            toggleQuickRecorderPopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            traceMenuAction("statusBarButtonClicked rightMouseUp -> contextMenu")
            closeQuickRecorderPopover()
            showContextMenu()
        default:
            traceMenuAction("statusBarButtonClicked \(event.type.rawValue) -> quickPopover")
            toggleQuickRecorderPopover()
        }
    }

    @objc private func startRecordingMenuAction(_ sender: Any?) {
        traceMenuAction("startRecordingMenuAction")
        startRecording()
    }

    @objc private func stopRecordingMenuAction(_ sender: Any?) {
        traceMenuAction("stopRecordingMenuAction")
        stopRecording()
    }

    @objc private func openLibraryMenuAction(_ sender: Any?) {
        traceMenuAction("openLibraryMenuAction")
        openLibrary()
    }

    @objc private func openSettingsMenuAction(_ sender: Any?) {
        traceMenuAction("openSettingsMenuAction")
        openSettings()
    }

    private func startRecording() {
        closeQuickRecorderPopover()
        Task {
            guard await ensureScreenRecordingPermissionIfNeeded() else {
                showError(ScreenCaptureError.permissionDenied)
                return
            }
            do {
                try await recordingEngine.startRecording()
                windowCoordinator.showOverlays()
            } catch {
                windowCoordinator.hideOverlays()
                recordingEngine.teardownQuickRecorderContext()
                showError(error)
            }
        }
    }

    private func stopRecording() {
        closeQuickRecorderPopover()
        Task {
            await recordingEngine.stopRecording()
            windowCoordinator.hideOverlays()
        }
    }

    private func openLibrary() {
        closeQuickRecorderPopover()
        // Defer until the status menu finishes its tracking loop.
        DispatchQueue.main.async { [weak self] in
            self?.activateAndPresentLibraryWindow()
        }
    }

    private func openSettings() {
        closeQuickRecorderPopover()
        // Defer until the status menu finishes its tracking loop.
        DispatchQueue.main.async { [weak self] in
            self?.activateAndPresentSettingsWindow()
        }
    }

    private func activateAndPresentLibraryWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openLibraryWindow()
        traceMenuAction("activateAndPresentLibraryWindow presenterInvoked")
    }

    private func activateAndPresentSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        openSettingsWindow()
        traceMenuAction("activateAndPresentSettingsWindow presenterInvoked")
    }

    private func showContextMenu() {
        guard let menu = statusBarMenu, let item = statusItem else { return }
        traceMenuAction("showContextMenu begin")
        item.menu = menu
        item.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        guard menu == statusBarMenu else { return }
        traceMenuAction("menuDidClose")
        statusItem?.menu = nil
    }

    private func traceMenuAction(_ message: String) {
        guard let menuActionTracePath, !menuActionTracePath.isEmpty else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(timestamp) \(message)\n"
        let url = URL(fileURLWithPath: menuActionTracePath)
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: menuActionTracePath),
               let handle = try? FileHandle(forWritingTo: url)
            {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                    try handle.close()
                } catch {
                    try? data.write(to: url, options: .atomic)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func toggleQuickRecorderPopover() {
        guard let button = statusItem?.button else { return }

        if quickRecorderPopover.isShown {
            closeQuickRecorderPopover()
            return
        }

        let view = QuickRecorderPopoverView(
            onStartRecording: { [weak self] in self?.startRecording() },
            onCameraVisibilityChanged: { [weak self] in self?.windowCoordinator.refreshQuickPreviewBubble() }
        )
        .environment(recordingEngine)
        .environment(permissionManager)

        quickRecorderPopover.contentViewController = NSHostingController(rootView: view)
        quickRecorderPopover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func closeQuickRecorderPopover() {
        guard quickRecorderPopover.isShown else { return }
        quickRecorderPopover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        stopPopoverDismissMonitors()
        quickPreviewTask?.cancel()
        quickPreviewTask = nil
        recordingEngine.teardownQuickRecorderContext()
        windowCoordinator.hideQuickPreviewBubble()
    }

    func popoverDidShow(_ notification: Notification) {
        startPopoverDismissMonitors()
        // Show the quick preview shell immediately; camera frames can start as setup completes.
        windowCoordinator.showQuickPreviewBubble()
        quickPreviewTask?.cancel()
        quickPreviewTask = Task { [weak self] in
            guard let self else { return }
            guard !Task.isCancelled, quickRecorderPopover.isShown else { return }
            await recordingEngine.prepareQuickRecorderContext()
            guard !Task.isCancelled, quickRecorderPopover.isShown else { return }
            windowCoordinator.refreshQuickPreviewBubble()
        }
    }

    private func showPendingRuntimeErrorIfNeeded() {
        guard let message = recordingEngine.consumeRuntimeErrorMessage() else { return }

        let alert = NSAlert()
        alert.messageText = "Recording Stopped"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func openLibraryForCompletedRecordingIfNeeded() {
        guard recordingEngine.lastCompletedURL != nil else { return }
        openLibrary()
    }

    private func showError(_ error: Error) {
        if suppressRecordingErrorAlerts {
            traceMenuAction("showError suppressed \(error.localizedDescription)")
            return
        }
        let alert = NSAlert()
        alert.messageText = "Recording Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }

    private func ensureScreenRecordingPermissionIfNeeded() async -> Bool {
        guard recordingEngine.settings.mode.includesScreen else { return true }
        await permissionManager.refresh()
        if permissionManager.screenRecording == .granted { return true }
        let granted = await permissionManager.requestScreenRecording()
        if !granted { permissionManager.openScreenRecordingSettings() }
        return granted
    }

    // MARK: - Popover Dismissal Monitoring

    private func startPopoverDismissMonitors() {
        stopPopoverDismissMonitors()

        localPopoverClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            handlePopoverInteraction(event)
            return event
        }

        globalPopoverClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                self?.handlePopoverInteraction(event)
            }
        }

        localPopoverKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard quickRecorderPopover.isShown else { return event }
            // Esc key
            if event.keyCode == 53 {
                closeQuickRecorderPopover()
                return nil
            }
            return event
        }
    }

    private func stopPopoverDismissMonitors() {
        if let monitor = localPopoverClickMonitor {
            NSEvent.removeMonitor(monitor)
            localPopoverClickMonitor = nil
        }
        if let monitor = globalPopoverClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalPopoverClickMonitor = nil
        }
        if let monitor = localPopoverKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localPopoverKeyMonitor = nil
        }
    }

    private func handlePopoverInteraction(_ event: NSEvent) {
        guard quickRecorderPopover.isShown else { return }
        guard let point = eventScreenPoint(event) else { return }
        if shouldKeepPopoverOpen(for: point) {
            return
        }
        closeQuickRecorderPopover()
    }

    private func shouldKeepPopoverOpen(for point: NSPoint) -> Bool {
        isPointInPopover(point) ||
            isPointInStatusItemButton(point) ||
            windowCoordinator.isPointInVisibleCameraBubble(point)
    }

    private func isPointInPopover(_ point: NSPoint) -> Bool {
        guard let window = quickRecorderPopover.contentViewController?.view.window else { return false }
        return window.frame.contains(point)
    }

    private func isPointInStatusItemButton(_ point: NSPoint) -> Bool {
        guard let button = statusItem?.button, let buttonWindow = button.window else { return false }
        let buttonRectInWindow = button.convert(button.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        return buttonRectOnScreen.contains(point)
    }

    private func eventScreenPoint(_ event: NSEvent) -> NSPoint? {
        if let window = event.window {
            return window.convertPoint(toScreen: event.locationInWindow)
        }
        return event.locationInWindow
    }
}

// MARK: - NSImage tinting

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        guard let image = copy() as? NSImage else { return self }
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
