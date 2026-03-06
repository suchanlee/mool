@testable import Mool
import XCTest

@MainActor
final class CameraBubbleWindowTests: XCTestCase {
    func testConstrainFrameRectClampsToVisibleFrame() {
        let window = CameraBubbleWindow(cameraManager: FakeCameraManager())
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            XCTFail("Expected at least one screen")
            return
        }

        let visible = screen.visibleFrame
        let candidate = NSRect(
            x: visible.maxX + 120,
            y: visible.maxY + 80,
            width: 220,
            height: 220
        )

        let constrained = window.constrainFrameRect(candidate, to: screen)

        XCTAssertEqual(constrained.maxX, visible.maxX, accuracy: 0.5)
        XCTAssertEqual(constrained.maxY, visible.maxY, accuracy: 0.5)
    }

    func testSetFrameOriginNotifiesFrameChange() {
        let window = CameraBubbleWindow(cameraManager: FakeCameraManager())
        var didChangeFrame = false
        window.onFrameChanged = {
            didChangeFrame = true
        }

        let nextOrigin = NSPoint(x: window.frame.origin.x - 40, y: window.frame.origin.y + 20)
        window.setFrameOrigin(nextOrigin)

        XCTAssertTrue(didChangeFrame)
    }
}
