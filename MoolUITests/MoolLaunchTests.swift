import XCTest

final class MoolLaunchTests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    func testAppLaunches_withoutCrashing() {
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }

    func testStatusBarItem_exists() {
        XCTAssertTrue(app.statusItems["Mool"].firstMatch.waitForExistence(timeout: 5))
    }

    func testStatusBarMenu_containsStartRecording() {
        let statusItem = openStatusMenu(in: app)
        XCTAssertTrue(statusItem.menuItems["status.startRecording"].firstMatch.exists)
        dismissStatusMenu(in: app)
    }

    func testStatusBarMenu_containsOpenLibrary() {
        let statusItem = openStatusMenu(in: app)
        XCTAssertTrue(statusItem.menuItems["status.openLibrary"].firstMatch.exists)
        dismissStatusMenu(in: app)
    }

    func testStatusBarMenu_containsSettings() {
        let statusItem = openStatusMenu(in: app)
        XCTAssertTrue(statusItem.menuItems["status.openSettings"].firstMatch.exists)
        dismissStatusMenu(in: app)
    }

    func testStatusBarMenu_containsQuit() {
        let statusItem = openStatusMenu(in: app)
        XCTAssertTrue(statusItem.menuItems["status.quit"].firstMatch.exists)
        dismissStatusMenu(in: app)
    }
}
