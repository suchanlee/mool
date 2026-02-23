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
}
