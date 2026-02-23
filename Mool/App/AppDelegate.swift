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

    // MARK: - Init

    override init() {
        self.recordingEngine = RecordingEngine(storageManager: storageManager)
        super.init()
    }

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent the app from appearing in the Dock until explicitly requested
        NSApp.setActivationPolicy(.accessory)

        // Build overlays first, then the menu bar
        let coordinator = WindowCoordinator(recordingEngine: recordingEngine)
        self.windowCoordinator = coordinator

        menuBarController = MenuBarController(
            recordingEngine: recordingEngine,
            windowCoordinator: coordinator,
            permissionManager: permissionManager
        )

        // Check permissions on launch (non-blocking)
        Task {
            await permissionManager.checkAllPermissions()
        }

        runUITestLaunchActionIfNeeded(coordinator: coordinator)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Stay alive even if all windows are closed (we live in the menu bar)
        return false
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
            for _ in 0..<12 {
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
            let selector = Selector(("showLibraryWindow:"))
            print("[UITest] showLibraryWindow target:", String(describing: NSApp.target(forAction: selector, to: nil, from: nil)))
            NSApp.sendAction(selector, to: nil, from: nil)
        case .openSettings:
            let selector = Selector(("showSettingsWindow:"))
            print("[UITest] showSettingsWindow target:", String(describing: NSApp.target(forAction: selector, to: nil, from: nil)))
            NSApp.sendAction(selector, to: nil, from: nil)
        case .openSourcePicker:
            coordinator.showSourcePicker()
        }
    }

    private func isUITestLaunchActionSatisfied(_ action: UITestLaunchAction) -> Bool {
        switch action {
        case .openLibrary:
            return NSApp.windows.contains { $0.isVisible && $0.title == "Library" }
        case .openSettings:
            return NSApp.windows.contains {
                $0.isVisible && ($0.title.contains("Settings") || $0.title.contains("Preferences"))
            }
        case .openSourcePicker:
            return NSApp.windows.contains { $0.isVisible && $0.title == "New Recording" }
        }
    }
}

private enum UITestLaunchAction {
    case openLibrary
    case openSettings
    case openSourcePicker
    }
