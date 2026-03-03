import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Singletons (owned here, injected via env)

    let permissionManager = PermissionManager()
    let storageManager = StorageManager()
    let recordingEngine: RecordingEngine

    // MARK: - UI controllers

    private var menuBarController: MenuBarController?
    private var windowCoordinator: WindowCoordinator?
    private var libraryWindow: NSWindow?
    private var settingsWindow: NSWindow?

    // MARK: - Init

    override init() {
        recordingEngine = RecordingEngine(storageManager: storageManager)
        super.init()
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent the app from appearing in the Dock until explicitly requested
        NSApp.setActivationPolicy(.accessory)

        // Build overlays first, then the menu bar
        let coordinator = WindowCoordinator(
            recordingEngine: recordingEngine,
            permissionManager: permissionManager
        )
        windowCoordinator = coordinator

        menuBarController = MenuBarController(
            recordingEngine: recordingEngine,
            windowCoordinator: coordinator,
            permissionManager: permissionManager,
            openLibraryWindow: { [weak self] in
                self?.presentLibraryWindow()
            },
            openSettingsWindow: { [weak self] in
                self?.presentSettingsWindow()
            }
        )

        // Refresh permission state on launch (non-blocking), then apply defaults.
        Task {
            await permissionManager.refresh()
            applyUndeterminedAVPermissionDefaults()
        }

        runUITestLaunchActionIfNeeded(coordinator: coordinator)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay alive even if all windows are closed (we live in the menu bar)
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure any in-progress recording is cleanly finished
        if recordingEngine.state == .recording || recordingEngine.state == .paused {
            // Fire-and-forget stop; the file may be truncated but we avoid data loss
            Task { await recordingEngine.stopRecording() }
        }
    }

    // MARK: - Login item

    func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("[AppDelegate] Login item toggle failed: \(error)")
        }
    }

    // MARK: - UI Test Hooks

    private func runUITestLaunchActionIfNeeded(coordinator: WindowCoordinator) {
        let args = Set(ProcessInfo.processInfo.arguments)
        let action: UITestLaunchAction
        if args.contains("UITEST_OPEN_LIBRARY") {
            action = .openLibrary
        } else if args.contains("UITEST_OPEN_SETTINGS") {
            action = .openSettings
        } else if args.contains("UITEST_OPEN_SOURCE_PICKER") {
            action = .openSourcePicker
        } else {
            return
        }

        Task {
            // Window scene routing can be delayed right after launch.
            // Retry for a short period so UI tests can reliably start on the intended screen.
            for _ in 0 ..< 12 {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                performUITestLaunchAction(action, coordinator: coordinator)

                if isUITestLaunchActionSatisfied(action) {
                    return
                }

                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }

    private func performUITestLaunchAction(_ action: UITestLaunchAction, coordinator: WindowCoordinator) {
        switch action {
        case .openLibrary:
            presentLibraryWindow()
        case .openSettings:
            presentSettingsWindow()
        case .openSourcePicker:
            coordinator.showSourcePicker()
        }
    }

    private func isUITestLaunchActionSatisfied(_ action: UITestLaunchAction) -> Bool {
        switch action {
        case .openLibrary:
            NSApp.windows.contains { $0.isVisible && $0.title == "Library" }
        case .openSettings:
            NSApp.windows.contains {
                $0.isVisible && ($0.title.contains("Settings") || $0.title.contains("Preferences"))
            }
        case .openSourcePicker:
            NSApp.windows.contains { $0.isVisible && $0.title == "New Recording" }
        }
    }

    private func applyUndeterminedAVPermissionDefaults() {
        if permissionManager.camera == .notDetermined, recordingEngine.settings.mode.includesCamera {
            recordingEngine.setCameraEnabled(false)
        }

        if permissionManager.microphone == .notDetermined, recordingEngine.settings.captureMicrophone {
            recordingEngine.settings.captureMicrophone = false
            recordingEngine.settings.save()
        }
    }

    private func presentLibraryWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = NSApp.windows.first(where: { $0.title == "Library" }) {
            existing.makeKeyAndOrderFront(nil)
            libraryWindow = existing
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Library"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: LibraryView()
                .environment(storageManager)
                .environment(recordingEngine)
        )
        window.makeKeyAndOrderFront(nil)
        libraryWindow = window
    }

    private func presentSettingsWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if let existing = NSApp.windows.first(where: {
            $0.title.contains("Settings") || $0.title.contains("Preferences")
        }) {
            existing.makeKeyAndOrderFront(nil)
            settingsWindow = existing
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView()
                .environment(recordingEngine)
                .environment(storageManager)
        )
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}

private enum UITestLaunchAction {
    case openLibrary
    case openSettings
    case openSourcePicker
}
