import CoreGraphics
@testable import Mool
import XCTest

final class CountdownTargetResolverTests: XCTestCase {
    func testResolve_returnsAppKitDisplayFrameForDisplayCapture() {
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
                .init(
                    displayID: 10,
                    appKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    captureFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
                ),
                .init(
                    displayID: 20,
                    appKitFrame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
                    captureFrame: CGRect(x: 1440, y: 160, width: 1440, height: 900)
                )
            ]
        )

        XCTAssertEqual(
            result,
            [.init(displayID: 20, frame: CGRect(x: 1440, y: 0, width: 1440, height: 900))]
        )
    }

    func testResolve_convertsSelectedWindowFrameIntoAppKitCoordinates() {
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
                .init(
                    displayID: 10,
                    appKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    captureFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
                ),
                .init(
                    displayID: 20,
                    appKitFrame: CGRect(x: 1440, y: 0, width: 1440, height: 900),
                    captureFrame: CGRect(x: 1440, y: 0, width: 1440, height: 900)
                )
            ]
        )

        XCTAssertEqual(
            result,
            [.init(displayID: 20, frame: CGRect(x: 1550, y: 180, width: 800, height: 600))]
        )
    }

    func testResolve_returnsNoTargetsWhenScreenCaptureDisabled() {
        let result = CountdownTargetResolver.resolveTargets(
            modeIncludesScreen: false,
            selectedDisplayIndex: 0,
            selectedWindowID: nil,
            availableDisplays: [.init(displayID: 10)],
            availableWindows: [],
            connectedScreens: [
                .init(
                    displayID: 10,
                    appKitFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                    captureFrame: CGRect(x: 0, y: 0, width: 1440, height: 900)
                )
            ]
        )

        XCTAssertEqual(result, [])
    }

    func testCameraOverlayLayout_normalizesBubbleFrameWithinCaptureTarget() {
        let result = CameraOverlayLayoutResolver.normalizedFrame(
            overlayFrame: CGRect(x: 860, y: 240, width: 220, height: 220),
            within: CGRect(x: 400, y: 120, width: 1100, height: 880)
        )

        guard let result else {
            return XCTFail("Expected a normalized overlay frame")
        }

        XCTAssertEqual(result.origin.x, 460.0 / 1100.0, accuracy: 0.0001)
        XCTAssertEqual(result.origin.y, 120.0 / 880.0, accuracy: 0.0001)
        XCTAssertEqual(result.width, 220.0 / 1100.0, accuracy: 0.0001)
        XCTAssertEqual(result.height, 220.0 / 880.0, accuracy: 0.0001)
    }

    func testCameraOverlayLayout_defaultFrameAnchorsBubbleInsideTarget() {
        let result = CameraOverlayLayoutResolver.defaultFrame(
            for: CGSize(width: 220, height: 220),
            inside: CGRect(x: 400, y: 120, width: 1100, height: 880)
        )

        XCTAssertEqual(result, CGRect(x: 1256, y: 144, width: 220, height: 220))
    }
}
