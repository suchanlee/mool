import XCTest

extension XCTestCase {
    /// Opens the app's status item menu with retries to reduce flakiness.
    func openStatusMenu(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> XCUIElement {
        let statusItem = app.statusItems["Mool"].firstMatch
        XCTAssertTrue(statusItem.waitForExistence(timeout: 5), "Status item not found", file: file, line: line)

        let menuSentinel = statusItem.menuItems["status.openLibrary"].firstMatch
        for _ in 0..<5 {
            if statusItem.isHittable {
                statusItem.click()
            } else {
                statusItem.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
            }

            if menuSentinel.waitForExistence(timeout: 0.6) {
                return statusItem
            }

            app.typeKey(.escape, modifierFlags: [])
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        }

        XCTFail("Failed to open status item menu", file: file, line: line)
        return statusItem
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
        for _ in 0..<3 {
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
