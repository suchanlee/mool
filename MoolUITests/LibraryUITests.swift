import XCTest

final class LibraryUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.activate()
        clickStatusMenuItem("status.openLibrary", in: app)
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Tests

    func testOpenLibrary_windowAppears() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 8))
    }

    func testLibrary_showsContent() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 8) else {
            XCTFail("Library window did not appear")
            return
        }

        // Depending on local files, library can show an empty state or a recordings list.
        let emptyState = window.staticTexts["No Recordings Yet"]
        let recordingsList = window.tables.firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 2) || recordingsList.exists)
    }
}
