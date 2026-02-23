import XCTest

final class LibraryUITests: XCTestCase {

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

    private func openLibrary() {
        app.statusItems["Mool"].click()
        app.menuItems["Open Library"].click()
    }

    // MARK: - Tests

    func testOpenLibrary_windowAppears() {
        openLibrary()
        let window = app.windows["Library"]
        XCTAssertTrue(window.waitForExistence(timeout: 3))
    }

    func testLibrary_withNoRecordings_showsEmptyState() {
        openLibrary()
        let window = app.windows["Library"]
        guard window.waitForExistence(timeout: 3) else {
            XCTFail("Library window did not appear")
            return
        }
        // The library shows "No Recordings Yet" when the recordings folder is empty
        let emptyLabel = window.staticTexts["No Recordings Yet"]
        XCTAssertTrue(emptyLabel.waitForExistence(timeout: 2))
    }
}
