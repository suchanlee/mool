import AppKit
import Foundation
import XCTest

final class StatusMenuActionsUITests: XCTestCase {
    private static let appBundleIdentifier = "com.mool.app"
    private var app: XCUIApplication?
    private var tempFiles: [URL] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateRunningMoolInstances()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        app = nil
        for fileURL in tempFiles {
            try? FileManager.default.removeItem(at: fileURL)
        }
        tempFiles.removeAll()
    }

    func testRightClickMenuOpenLibraryAndSettings() {
        let statusTraceURL = makeTraceURL(prefix: "mool-status-menu-trace")
        let app = launchApp(
            environment: [
                "MOOL_STATUS_MENU_TRACE_PATH": statusTraceURL.path
            ]
        )

        clickStatusMenuItem("status.openLibrary", in: app)
        XCTAssertTrue(
            waitForTraceEntry("openLibraryMenuAction", in: statusTraceURL),
            "Missing openLibraryMenuAction trace"
        )
        XCTAssertTrue(
            waitForTraceEntry("activateAndPresentLibraryWindow presenterInvoked", in: statusTraceURL),
            "Missing library presenter trace"
        )

        let libraryWindow = app.windows.matching(NSPredicate(format: "title == %@", "Library")).firstMatch
        let libraryTrace = loadTraceContents(from: statusTraceURL) ?? ""
        XCTAssertTrue(
            libraryWindow.waitForExistence(timeout: 8),
            "Library window did not appear. Trace:\n\(libraryTrace)"
        )

        clickStatusMenuItem("status.openSettings", in: app)
        XCTAssertTrue(
            waitForTraceEntry("openSettingsMenuAction", in: statusTraceURL),
            "Missing openSettingsMenuAction trace"
        )
        XCTAssertTrue(
            waitForTraceEntry("activateAndPresentSettingsWindow presenterInvoked", in: statusTraceURL),
            "Missing settings presenter trace"
        )

        let settingsWindow = app.windows.matching(NSPredicate(format: "title CONTAINS %@ OR title CONTAINS %@", "Settings", "Preferences"))
            .firstMatch
        let settingsTrace = loadTraceContents(from: statusTraceURL) ?? ""
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 8),
            "Settings window did not appear. Trace:\n\(settingsTrace)"
        )
    }

    func testQuickRecorderStart_whenScreenPermissionDenied_opensSettingsPromptFlow() {
        let permissionTraceURL = makeTraceURL(prefix: "mool-permission-trace")
        let recordingTraceURL = makeTraceURL(prefix: "mool-recording-trace")
        let statusTraceURL = makeTraceURL(prefix: "mool-status-menu-trace")
        let app = launchApp(
            environment: [
                "MOOL_TEST_SCREEN_PERMISSION": "denied",
                "MOOL_TEST_CAMERA_PERMISSION": "granted",
                "MOOL_TEST_MIC_PERMISSION": "granted",
                "MOOL_TEST_DISABLE_SYSTEM_SETTINGS_OPEN": "1",
                "MOOL_PERMISSION_TRACE_PATH": permissionTraceURL.path,
                "MOOL_RECORDING_TEST_MODE": "stub_success",
                "MOOL_RECORDING_TRACE_PATH": recordingTraceURL.path,
                "MOOL_STATUS_MENU_TRACE_PATH": statusTraceURL.path
            ]
        )

        let startButton = openQuickRecorderPopover(in: app)
        XCTAssertTrue(
            waitForElementLabel(startButton, equals: "Record (need permission)"),
            "Unexpected quick recorder button label: \(startButton.label)"
        )
        flipQuickRecorderToggle("quickRecorder.toggle.camera", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.camera", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.microphone", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.microphone", in: app)
        XCTAssertFalse(
            waitForTraceEntry("requestScreenRecording", in: permissionTraceURL, timeout: 1),
            "Screen permission should not be requested when opening the popover"
        )
        XCTAssertFalse(
            waitForTraceEntry("openCameraSettings", in: permissionTraceURL, timeout: 1),
            "Camera settings should not open when camera permission is granted"
        )
        XCTAssertFalse(
            waitForTraceEntry("openMicrophoneSettings", in: permissionTraceURL, timeout: 1),
            "Microphone settings should not open when microphone permission is granted"
        )
        click(startButton)

        XCTAssertTrue(
            waitForTraceEntry("requestScreenRecording override=denied", in: permissionTraceURL),
            "Missing denied requestScreenRecording trace"
        )
        XCTAssertTrue(
            waitForTraceEntry("openScreenRecordingSettings", in: permissionTraceURL),
            "Expected screen settings open trace when permission is denied"
        )
        XCTAssertFalse(
            waitForTraceEntry("startRecordingStubSuccess", in: recordingTraceURL, timeout: 1),
            "Recording unexpectedly started while screen permission was denied"
        )
        XCTAssertFalse(
            waitForTraceEntry("showError ", in: statusTraceURL, timeout: 1),
            "Permission-denied flow should not show a recording failed alert"
        )
    }

    func testQuickRecorderStart_whenScreenPermissionGranted_startsWithoutOpeningSettings() {
        let permissionTraceURL = makeTraceURL(prefix: "mool-permission-trace")
        let recordingTraceURL = makeTraceURL(prefix: "mool-recording-trace")
        let app = launchApp(
            environment: [
                "MOOL_TEST_SCREEN_PERMISSION": "granted",
                "MOOL_TEST_CAMERA_PERMISSION": "granted",
                "MOOL_TEST_MIC_PERMISSION": "granted",
                "MOOL_TEST_DISABLE_SYSTEM_SETTINGS_OPEN": "1",
                "MOOL_PERMISSION_TRACE_PATH": permissionTraceURL.path,
                "MOOL_RECORDING_TEST_MODE": "stub_success",
                "MOOL_RECORDING_TRACE_PATH": recordingTraceURL.path
            ]
        )

        let startButton = openQuickRecorderPopover(in: app)
        XCTAssertTrue(
            waitForElementLabel(startButton, equals: "Record"),
            "Unexpected quick recorder button label: \(startButton.label)"
        )
        flipQuickRecorderToggle("quickRecorder.toggle.camera", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.camera", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.microphone", in: app)
        flipQuickRecorderToggle("quickRecorder.toggle.microphone", in: app)
        XCTAssertFalse(
            waitForTraceEntry("requestScreenRecording", in: permissionTraceURL, timeout: 1),
            "Screen permission should not be requested when opening the popover"
        )
        XCTAssertFalse(
            waitForTraceEntry("openCameraSettings", in: permissionTraceURL, timeout: 1),
            "Camera settings should not open when camera permission is granted"
        )
        XCTAssertFalse(
            waitForTraceEntry("openMicrophoneSettings", in: permissionTraceURL, timeout: 1),
            "Microphone settings should not open when microphone permission is granted"
        )
        click(startButton)

        XCTAssertTrue(
            waitForTraceEntry("refreshScreenRecording override=granted", in: permissionTraceURL),
            "Missing granted refresh trace"
        )
        XCTAssertFalse(
            waitForTraceEntry("openScreenRecordingSettings", in: permissionTraceURL, timeout: 1),
            "System settings should not open when permission is already granted"
        )
        XCTAssertFalse(
            waitForTraceEntry("requestScreenRecording override=granted", in: permissionTraceURL, timeout: 1),
            "requestScreenRecording should not run when permission is already granted"
        )
        XCTAssertTrue(
            waitForTraceEntry("startRecordingStubSuccess", in: recordingTraceURL),
            "Recording did not start in granted flow"
        )
    }

    private func loadTraceContents(from traceURL: URL) -> String? {
        let timeout = Date().addingTimeInterval(5)
        while Date() < timeout {
            if let data = try? Data(contentsOf: traceURL), !data.isEmpty {
                return String(decoding: data, as: UTF8.self)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    private func waitForTraceEntry(_ token: String, in traceURL: URL, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let data = try? Data(contentsOf: traceURL), !data.isEmpty {
                let trace = String(decoding: data, as: UTF8.self)
                if trace.contains(token) {
                    return true
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func makeTraceURL(prefix: String) -> URL {
        let traceURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString).log")
        try? FileManager.default.removeItem(at: traceURL)
        tempFiles.append(traceURL)
        return traceURL
    }

    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        for (key, value) in environment {
            app.launchEnvironment[key] = value
        }
        app.launch()
        app.activate()
        self.app = app
        return app
    }

    private func flipQuickRecorderToggle(_ identifier: String, in app: XCUIApplication) {
        let toggle = app.buttons[identifier].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 2), "Toggle '\(identifier)' not found")
        let initialLabel = toggle.label
        click(toggle)
        XCTAssertTrue(
            waitForElementLabel(toggle, differsFrom: initialLabel, timeout: 3),
            "Toggle '\(identifier)' did not change state from '\(initialLabel)'"
        )
    }

    private func waitForElementLabel(
        _ element: XCUIElement,
        equals expectedLabel: String,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label == expectedLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func waitForElementLabel(
        _ element: XCUIElement,
        differsFrom previousLabel: String,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label != previousLabel {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func click(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    private func terminateRunningMoolInstances() {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let runningApps = NSRunningApplication.runningApplications(
                withBundleIdentifier: Self.appBundleIdentifier
            )
            if runningApps.isEmpty { return }
            for runningApp in runningApps {
                if !runningApp.terminate() {
                    _ = runningApp.forceTerminate()
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
