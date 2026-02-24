import AppKit
import SwiftUI

// MARK: - Menu Bar Controller

/// Manages the NSStatusItem (menu bar icon) and associated menu/popover.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private var statusItem: NSStatusItem?
    private var statusBarMenu: NSMenu?
    private let quickRecorderPopover = NSPopover()
    private var stateObserverTimer: Timer?
    private var quickPreviewTask: Task<Void, Never>?
    private var lastHandledCompletedRecordingURL: URL?
    private var localPopoverClickMonitor: Any?
    private var globalPopoverClickMonitor: Any?
    private var localPopoverKeyMonitor: Any?

    private unowned let recordingEngine: RecordingEngine
    private unowned let windowCoordinator: WindowCoordinator
    private unowned let permissionManager: PermissionManager

    // MARK: - Init

    init(
        recordingEngine: RecordingEngine,
        windowCoordinator: WindowCoordinator,
        permissionManager: PermissionManager
    ) {
        self.recordingEngine = recordingEngine
        self.windowCoordinator = windowCoordinator
        self.permissionManager = permissionManager
        super.init()
        setupStatusItem()
        observeRecordingState()
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

        let startItem = menu.addItem(withTitle: "Start Recording", action: #selector(startRecording), keyEquivalent: "")
        startItem.target = self
        startItem.identifier = NSUserInterfaceItemIdentifier("status.startRecording")

        let stopItem = menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
        stopItem.target = self
        stopItem.identifier = NSUserInterfaceItemIdentifier("status.stopRecording")

        menu.addItem(.separator())

        let libraryItem = menu.addItem(withTitle: "Open Library", action: #selector(openLibrary), keyEquivalent: "")
        libraryItem.target = self
        libraryItem.identifier = NSUserInterfaceItemIdentifier("status.openLibrary")

        let settingsItem = menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.identifier = NSUserInterfaceItemIdentifier("status.openSettings")

        menu.addItem(.separator())

        let quitItem = menu.addItem(withTitle: "Quit Mool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.identifier = NSUserInterfaceItemIdentifier("status.quit")

        statusBarMenu = menu
    }

    // MARK: - State observation

    private func observeRecordingState() {
        stateObserverTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuState()
                self?.updateStatusIcon()
                self?.showPendingRuntimeErrorIfNeeded()
                self?.openLibraryForCompletedRecordingIfNeeded()
            }
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
            toggleQuickRecorderPopover()
            return
        }

        switch event.type {
        case .rightMouseUp:
            closeQuickRecorderPopover()
            showContextMenu()
        default:
            toggleQuickRecorderPopover()
        }
    }

    @objc private func startRecording() {
        closeQuickRecorderPopover()
        Task {
            do {
                try await recordingEngine.startRecording()
                windowCoordinator.showOverlays()
            } catch {
                showError(error)
            }
        }
    }

    @objc private func stopRecording() {
        closeQuickRecorderPopover()
        Task {
            await recordingEngine.stopRecording()
            windowCoordinator.hideOverlays()
        }
    }

    @objc private func openLibrary() {
        closeQuickRecorderPopover()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Library" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NSApp.sendAction(Selector(("showLibraryWindow:")), to: nil, from: self)
        }
    }

    @objc private func openSettings() {
        closeQuickRecorderPopover()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func showContextMenu() {
        guard let menu = statusBarMenu, let item = statusItem else { return }
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
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
        quickPreviewTask?.cancel()
        quickPreviewTask = Task { [weak self] in
            guard let self else { return }
            await recordingEngine.prepareQuickRecorderContext()
            guard !Task.isCancelled, quickRecorderPopover.isShown else { return }
            windowCoordinator.showQuickPreviewBubble()
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
        guard recordingEngine.state == .idle else { return }
        guard let completedURL = recordingEngine.lastCompletedURL else { return }
        guard completedURL != lastHandledCompletedRecordingURL else { return }

        lastHandledCompletedRecordingURL = completedURL
        openLibrary()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Recording Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
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
