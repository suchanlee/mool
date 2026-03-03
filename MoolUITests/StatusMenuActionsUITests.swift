import Foundation
import XCTest

final class StatusMenuActionsUITests: XCTestCase {
    private var app: XCUIApplication!
    private var traceURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false

        traceURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("mool-status-menu-trace-\(UUID().uuidString).log")
        try? FileManager.default.removeItem(at: traceURL)

        app = XCUIApplication()
        app.launchEnvironment["MOOL_STATUS_MENU_TRACE_PATH"] = traceURL.path
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        if let traceURL {
            try? FileManager.default.removeItem(at: traceURL)
        }
        traceURL = nil
    }

    func testRightClickMenuOpenLibraryAndSettings() {
        clickStatusMenuItem("status.openLibrary", in: app)
        XCTAssertTrue(waitForTraceEntry("openLibraryMenuAction"), "Missing openLibraryMenuAction trace")
        XCTAssertTrue(waitForTraceEntry("activateAndPresentLibraryWindow presenterInvoked"), "Missing library presenter trace")

        let libraryWindow = app.windows.matching(NSPredicate(format: "title == %@", "Library")).firstMatch
        let libraryTrace = (try? loadTraceContents()) ?? ""
        XCTAssertTrue(
            libraryWindow.waitForExistence(timeout: 8),
            "Library window did not appear. Trace:\n\(libraryTrace)"
        )

        clickStatusMenuItem("status.openSettings", in: app)
        XCTAssertTrue(waitForTraceEntry("openSettingsMenuAction"), "Missing openSettingsMenuAction trace")
        XCTAssertTrue(waitForTraceEntry("activateAndPresentSettingsWindow presenterInvoked"), "Missing settings presenter trace")

        let settingsWindow = app.windows.matching(NSPredicate(format: "title CONTAINS %@ OR title CONTAINS %@", "Settings", "Preferences"))
            .firstMatch
        let settingsTrace = (try? loadTraceContents()) ?? ""
        XCTAssertTrue(
            settingsWindow.waitForExistence(timeout: 8),
            "Settings window did not appear. Trace:\n\(settingsTrace)"
        )
    }

    private func loadTraceContents() throws -> String {
        let timeout = Date().addingTimeInterval(5)
        while Date() < timeout {
            if let data = try? Data(contentsOf: traceURL), !data.isEmpty {
                return String(decoding: data, as: UTF8.self)
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return ""
    }

    private func waitForTraceEntry(_ token: String, timeout: TimeInterval = 5) -> Bool {
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
}
