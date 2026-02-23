import XCTest

final class SourcePickerUITests: XCTestCase {

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

    private func openSourcePicker() throws {
        app.statusItems["Mool"].click()
        let startItem = app.menuItems["Start Recording"]
        guard startItem.isEnabled else {
            throw XCTSkip("Start Recording is not enabled — app may already be recording")
        }
        startItem.click()
    }

    // MARK: - Tests

    func testStartRecording_opensSourcePicker() throws {
        try openSourcePicker()
        let picker = app.windows.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 3))
    }

    func testSourcePicker_hasModeCards() throws {
        try openSourcePicker()
        let picker = app.windows.firstMatch
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Source picker window did not appear")
            return
        }
        // Mode cards are identified by "modeCard.<rawValue>" accessibility identifiers
        let screenAndCameraCard = picker.buttons["modeCard.Screen + Camera"]
        XCTAssertTrue(screenAndCameraCard.waitForExistence(timeout: 2))
    }

    func testSourcePicker_hasRecordButton() throws {
        try openSourcePicker()
        let picker = app.windows.firstMatch
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Source picker window did not appear")
            return
        }
        let recordButton = picker.buttons["sourcePicker.record"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 2))
    }

    func testSourcePicker_hasCancelButton() throws {
        try openSourcePicker()
        let picker = app.windows.firstMatch
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Source picker window did not appear")
            return
        }
        XCTAssertTrue(picker.buttons["Cancel"].exists)
    }

    func testSourcePicker_cancelButton_dismissesPicker() throws {
        try openSourcePicker()
        let picker = app.windows.firstMatch
        guard picker.waitForExistence(timeout: 3) else {
            XCTFail("Source picker window did not appear")
            return
        }
        picker.buttons["Cancel"].click()
        XCTAssertFalse(picker.waitForExistence(timeout: 2))
    }
}
