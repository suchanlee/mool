import AppKit
import SwiftUI
import Combine

// MARK: - Menu Bar Controller

/// Manages the NSStatusItem (menu bar icon) and associated menu/popover.
@MainActor
final class MenuBarController {

    private var statusItem: NSStatusItem?
    private var statusBarMenu: NSMenu?
    private var cancellables: Set<AnyCancellable> = []

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

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(withTitle: "Start Recording", action: #selector(startRecording), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Stop Recording", action: #selector(stopRecording), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open Library", action: #selector(openLibrary), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Mool", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusBarMenu = menu
        statusItem?.menu = menu
    }

    // MARK: - State observation

    private func observeRecordingState() {
        // Use withObservationTracking to watch @Observable state
        // We poll via Timer as a simple approach for menu updates
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuState()
                self?.updateStatusIcon()
            }
        }
    }

    private func updateMenuState() {
        guard let menu = statusBarMenu else { return }
        let isIdle = recordingEngine.state == .idle
        let isRecording = recordingEngine.state == .recording

        menu.items[0].isEnabled = isIdle
        menu.items[1].isEnabled = isRecording || recordingEngine.state == .paused
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        switch recordingEngine.state {
        case .recording:
            button.image = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
            button.image?.isTemplate = false
            // Tint red
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
        // The menu is already set on statusItem; clicking opens it automatically.
        // This action handler is reserved for future popover support.
    }

    @objc private func startRecording() {
        windowCoordinator.showSourcePicker()
    }

    @objc private func stopRecording() {
        Task {
            await recordingEngine.stopRecording()
            windowCoordinator.hideOverlays()
        }
    }

    @objc private func openLibrary() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        // Open the library window
        if let window = NSApp.windows.first(where: { $0.title == "Library" }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open via SwiftUI window group
            NSApp.sendAction(Selector(("showLibraryWindow:")), to: nil, from: self)
        }
    }

    @objc private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Recording Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - NSImage tinting

extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
