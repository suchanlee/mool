import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Helpers

    private func openSettings() {
        app.statusItems["Mool"].click()
        app.menuItems["Settings…"].click()
    }

    // MARK: - Tests

    func testOpenSettings_windowAppears() {
        openSettings()
        // Settings window may be titled "Settings" (macOS 13+) or "Preferences"
        let settingsWindow = app.windows.firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 3))
    }

    func testSettingsWindow_hasRecordingTab() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        XCTAssertTrue(settingsWindow.buttons["Recording"].exists)
    }

    func testSettingsWindow_hasShortcutsTab() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        XCTAssertTrue(settingsWindow.buttons["Shortcuts"].exists)
    }

    func testSettingsWindow_hasStorageTab() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        XCTAssertTrue(settingsWindow.buttons["Storage"].exists)
    }

    func testSettingsWindow_hasAboutTab() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        XCTAssertTrue(settingsWindow.buttons["About"].exists)
    }

    func testRecordingTab_showsDefaultModeLabel() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        // Recording tab is selected by default
        XCTAssertTrue(settingsWindow.staticTexts["Default Mode"].exists)
    }

    func testNavigateToAboutTab_showsMoolTitle() {
        openSettings()
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 3) else {
            XCTFail("Settings window did not appear")
            return
        }
        settingsWindow.buttons["About"].click()
        XCTAssertTrue(settingsWindow.staticTexts["Mool"].waitForExistence(timeout: 2))
    }
}
