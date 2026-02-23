import XCTest

final class SourcePickerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["UITEST_OPEN_SOURCE_PICKER"]
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    // MARK: - Tests

    private func waitForSourcePicker(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let picker = app.windows.firstMatch
        guard picker.waitForExistence(timeout: 8) else {
            XCTFail("Source picker window did not appear", file: file, line: line)
            return picker
        }
        return picker
    }

    func testStartRecording_opensSourcePicker() {
        XCTAssertTrue(waitForSourcePicker().exists)
    }

    func testSourcePicker_hasModeCards() {
        _ = waitForSourcePicker()
        let modeCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "modeCard.")).firstMatch
        XCTAssertTrue(modeCard.waitForExistence(timeout: 2))
    }

    func testSourcePicker_hasRecordButton() {
        let picker = waitForSourcePicker()
        let recordButton = picker.buttons["sourcePicker.record"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 2))
    }

    func testSourcePicker_hasCancelButton() {
        let picker = waitForSourcePicker()
        XCTAssertTrue(picker.buttons["Cancel"].exists)
    }

    func testSourcePicker_cancelButton_dismissesPicker() {
        let picker = waitForSourcePicker()
        picker.buttons["Cancel"].click()
        XCTAssertFalse(picker.waitForExistence(timeout: 2))
    }
}
