import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.activate()
        clickStatusMenuItem("status.openSettings", in: app)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Tests

    private func waitForSettingsWindow(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let settingsWindow = app.windows.firstMatch
        guard settingsWindow.waitForExistence(timeout: 8) else {
            XCTFail("Settings window did not appear", file: file, line: line)
            return settingsWindow
        }
        return settingsWindow
    }

    func testOpenSettings_windowAppears() {
        XCTAssertTrue(waitForSettingsWindow().exists)
    }

    func testSettingsWindow_hasRecordingTab() {
        let settingsWindow = waitForSettingsWindow()
        XCTAssertTrue(settingsWindow.buttons["Recording"].exists)
    }

    func testSettingsWindow_hasShortcutsTab() {
        let settingsWindow = waitForSettingsWindow()
        XCTAssertTrue(settingsWindow.buttons["Shortcuts"].exists)
    }

    func testSettingsWindow_hasStorageTab() {
        let settingsWindow = waitForSettingsWindow()
        XCTAssertTrue(settingsWindow.buttons["Storage"].exists)
    }

    func testSettingsWindow_hasAboutTab() {
        let settingsWindow = waitForSettingsWindow()
        XCTAssertTrue(settingsWindow.buttons["About"].exists)
    }

    func testRecordingTab_showsDefaultModeLabel() {
        let settingsWindow = waitForSettingsWindow()
        // Recording tab is selected by default
        XCTAssertTrue(settingsWindow.staticTexts["Default Mode"].exists)
    }

    func testNavigateToAboutTab_showsMoolTitle() {
        let settingsWindow = waitForSettingsWindow()
        settingsWindow.buttons["About"].click()
        XCTAssertTrue(settingsWindow.staticTexts["Mool"].waitForExistence(timeout: 2))
    }
}
