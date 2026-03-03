import XCTest

extension XCTestCase {
    private func leftClickStatusItem(_ statusItem: XCUIElement) {
        if statusItem.isHittable {
            statusItem.click()
        } else {
            statusItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    private func rightClickStatusItem(_ statusItem: XCUIElement) {
        if statusItem.isHittable {
            statusItem.rightClick()
        } else {
            statusItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).rightClick()
        }
    }

    /// Opens the app's status item menu with retries to reduce flakiness.
    func openStatusMenu(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let statusItem = app.statusItems["Mool"].firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status item not found", file: file, line: line)

        let menuSentinel = statusItem.menuItems["status.openLibrary"].firstMatch
        for _ in 0 ..< 5 {
            rightClickStatusItem(statusItem)

            if menuSentinel.waitForExistence(timeout: 0.6) {
                return statusItem
            }

            app.typeKey(.escape, modifierFlags: [])
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        XCTFail("Failed to open status item menu", file: file, line: line)
        return statusItem
    }

    /// Opens the app's quick recorder popover with retries and returns the start button.
    func openQuickRecorderPopover(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let statusItem = app.statusItems["Mool"].firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status item not found", file: file, line: line)

        let startButton = app.buttons["quickRecorder.startRecording"].firstMatch
        for _ in 0 ..< 5 {
            leftClickStatusItem(statusItem)
            if startButton.waitForExistence(timeout: 0.8) {
                return startButton
            }

            app.typeKey(.escape, modifierFlags: [])
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        XCTFail("Failed to open quick recorder popover", file: file, line: line)
        return startButton
    }

    func clickQuickRecorderStart(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let startButton = openQuickRecorderPopover(in: app, file: file, line: line)
        XCTAssertTrue(startButton.waitForExistence(timeout: 2), "Quick recorder start button not found", file: file, line: line)
        if startButton.isHittable {
            startButton.click()
        } else {
            startButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    func statusMenuItem(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let statusItem = openStatusMenu(in: app, file: file, line: line)
        let item = statusItem.menuItems[identifier].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 2), "Menu item '\(identifier)' not found", file: file, line: line)
        return item
    }

    func clickStatusMenuItem(
        _ identifier: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for _ in 0 ..< 3 {
            let item = statusMenuItem(identifier, in: app, file: file, line: line)
            if !item.isEnabled {
                XCTFail("Menu item '\(identifier)' is disabled", file: file, line: line)
                return
            }

            // Avoid "open menu during menu traversal" races.
            RunLoop.current.run(until: Date().addingTimeInterval(0.12))

            if item.isHittable {
                item.click()
                return
            }

            item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            return
        }

        XCTFail("Failed to click status menu item '\(identifier)'", file: file, line: line)
    }

    func dismissStatusMenu(in app: XCUIApplication) {
        if app.statusItems["Mool"].firstMatch.menuItems["status.openLibrary"].exists {
            app.typeKey(.escape, modifierFlags: [])
        }
    }
}
