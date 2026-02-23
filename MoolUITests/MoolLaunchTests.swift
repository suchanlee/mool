import XCTest

final class MoolLaunchTests: XCTestCase {

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

    func testAppLaunches_withoutCrashing() {
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testStatusBarItem_exists() {
        let statusItem = app.statusItems["Mool"]
        XCTAssertTrue(statusItem.exists)
    }

    func testStatusBarMenu_containsStartRecording() {
        app.statusItems["Mool"].click()
        XCTAssertTrue(app.menuItems["Start Recording"].exists)
        // Dismiss menu
        app.typeKey(.escape, modifierFlags: [])
    }

    func testStatusBarMenu_containsOpenLibrary() {
        app.statusItems["Mool"].click()
        XCTAssertTrue(app.menuItems["Open Library"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testStatusBarMenu_containsSettings() {
        app.statusItems["Mool"].click()
        XCTAssertTrue(app.menuItems["Settings…"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }

    func testStatusBarMenu_containsQuit() {
        app.statusItems["Mool"].click()
        XCTAssertTrue(app.menuItems["Quit Mool"].exists)
        app.typeKey(.escape, modifierFlags: [])
    }
}
