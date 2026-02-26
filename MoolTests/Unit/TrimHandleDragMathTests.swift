@testable import Mool
import XCTest

final class TrimHandleDragMathTests: XCTestCase {
    func testResolveTargetHandleSelectsStartWhenPointerNearStart() {
        let target = TrimHandleDragMath.resolveTargetHandle(
            startLocationX: 102,
            startHandleCenterX: 100,
            endHandleCenterX: 260,
            hitAreaWidth: 44
        )

        XCTAssertEqual(target, .start)
    }

    func testResolveTargetHandleSelectsEndWhenPointerNearEnd() {
        let target = TrimHandleDragMath.resolveTargetHandle(
            startLocationX: 248,
            startHandleCenterX: 100,
            endHandleCenterX: 260,
            hitAreaWidth: 44
        )

        XCTAssertEqual(target, .end)
    }

    func testResolveTargetHandleReturnsNearestWhenRangesOverlap() {
        let target = TrimHandleDragMath.resolveTargetHandle(
            startLocationX: 118,
            startHandleCenterX: 100,
            endHandleCenterX: 130,
            hitAreaWidth: 44
        )

        XCTAssertEqual(target, .end)
    }

    func testResolveTargetHandleReturnsNilOutsideHandleHitAreas() {
        let target = TrimHandleDragMath.resolveTargetHandle(
            startLocationX: 180,
            startHandleCenterX: 100,
            endHandleCenterX: 260,
            hitAreaWidth: 44
        )

        XCTAssertNil(target)
    }

    func testResolveTargetHandleSelectsEndNearTrailingEdge() {
        let target = TrimHandleDragMath.resolveTargetHandle(
            startLocationX: 928,
            startHandleCenterX: 132,
            endHandleCenterX: 950,
            hitAreaWidth: 60
        )

        XCTAssertEqual(target, .end)
    }

    func testStartHandleDragMovesForward() {
        let updated = TrimHandleDragMath.updatedStartTime(
            origin: 0,
            translationWidth: 90,
            trackWidth: 300,
            duration: 12,
            endTime: 12,
            minimumSpan: 0.1
        )

        XCTAssertEqual(updated, 3.6, accuracy: 0.0001)
    }

    func testStartHandleDragClampsToEndMinusMinimumSpan() {
        let updated = TrimHandleDragMath.updatedStartTime(
            origin: 4,
            translationWidth: 400,
            trackWidth: 300,
            duration: 12,
            endTime: 8,
            minimumSpan: 0.5
        )

        XCTAssertEqual(updated, 7.5, accuracy: 0.0001)
    }

    func testEndHandleDragMovesBackward() {
        let updated = TrimHandleDragMath.updatedEndTime(
            origin: 10,
            translationWidth: -75,
            trackWidth: 300,
            duration: 12,
            startTime: 0,
            minimumSpan: 0.1
        )

        XCTAssertEqual(updated, 7, accuracy: 0.0001)
    }

    func testEndHandleDragClampsToStartPlusMinimumSpan() {
        let updated = TrimHandleDragMath.updatedEndTime(
            origin: 5,
            translationWidth: -500,
            trackWidth: 300,
            duration: 12,
            startTime: 4.6,
            minimumSpan: 0.5
        )

        XCTAssertEqual(updated, 5.1, accuracy: 0.0001)
    }

    func testEndHandleDragClampsToDuration() {
        let updated = TrimHandleDragMath.updatedEndTime(
            origin: 9,
            translationWidth: 500,
            trackWidth: 300,
            duration: 12,
            startTime: 2,
            minimumSpan: 0.5
        )

        XCTAssertEqual(updated, 12, accuracy: 0.0001)
    }
}
