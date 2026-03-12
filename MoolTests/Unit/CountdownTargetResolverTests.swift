import CoreGraphics
@testable import Mool
import XCTest

final class CountdownTargetResolverTests: XCTestCase {
    func testResolve_returnsSelectedDisplayFrameForDisplayCapture() {
        let result = CountdownTargetResolver.resolveTargets(
            modeIncludesScreen: true,
            selectedDisplayIndex: 1,
            selectedWindowID: nil,
            availableDisplays: [
                .init(displayID: 10),
                .init(displayID: 20)
            ],
            availableWindows: [],
            connectedScreens: [
                .init(displayID: 10, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
                .init(displayID: 20, frame: CGRect(x: 1440, y: 0, width: 1440, height: 900))
            ]
        )

        XCTAssertEqual(
            result,
            [.init(displayID: 20, frame: CGRect(x: 1440, y: 0, width: 1440, height: 900))]
        )
    }

    func testResolve_returnsSelectedWindowFrameForWindowCapture() {
        let result = CountdownTargetResolver.resolveTargets(
            modeIncludesScreen: true,
            selectedDisplayIndex: 0,
            selectedWindowID: 77,
            availableDisplays: [
                .init(displayID: 10),
                .init(displayID: 20)
            ],
            availableWindows: [
                .init(windowID: 77, frame: CGRect(x: 1550, y: 120, width: 800, height: 600))
            ],
            connectedScreens: [
                .init(displayID: 10, frame: CGRect(x: 0, y: 0, width: 1440, height: 900)),
                .init(displayID: 20, frame: CGRect(x: 1440, y: 0, width: 1440, height: 900))
            ]
        )

        XCTAssertEqual(
            result,
            [.init(displayID: 20, frame: CGRect(x: 1550, y: 120, width: 800, height: 600))]
        )
    }

    func testResolve_returnsNoTargetsWhenScreenCaptureDisabled() {
        let result = CountdownTargetResolver.resolveTargets(
            modeIncludesScreen: false,
            selectedDisplayIndex: 0,
            selectedWindowID: nil,
            availableDisplays: [.init(displayID: 10)],
            availableWindows: [],
            connectedScreens: [.init(displayID: 10, frame: CGRect(x: 0, y: 0, width: 1440, height: 900))]
        )

        XCTAssertEqual(result, [])
    }
}
