import XCTest
@testable import Mool

@MainActor
final class AnnotationManagerTests: XCTestCase {

    var manager: AnnotationManager!

    override func setUp() {
        super.setUp()
        manager = AnnotationManager()
    }

    // MARK: - Stroke lifecycle

    func testBeginStroke_alone_doesNotAddStroke() {
        manager.beginStroke(at: CGPoint(x: 10, y: 10))
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    func testContinueStroke_afterBegin_addsStroke() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        XCTAssertEqual(manager.strokes.count, 1)
    }

    func testContinueStroke_accumulatesPoints() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        manager.continueStroke(at: CGPoint(x: 2, y: 2))
        manager.continueStroke(at: CGPoint(x: 3, y: 3))
        XCTAssertEqual(manager.strokes[0].points.count, 4) // start + 3 continues
    }

    func testEndStroke_keepsStroke() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        manager.endStroke()
        XCTAssertEqual(manager.strokes.count, 1)
    }

    func testMultipleStrokes_counted() {
        for i in 0..<3 {
            manager.beginStroke(at: CGPoint(x: Double(i * 10), y: 0))
            manager.continueStroke(at: CGPoint(x: Double(i * 10 + 1), y: 1))
            manager.endStroke()
        }
        XCTAssertEqual(manager.strokes.count, 3)
    }

    // MARK: - Tool differences

    func testPenTool_isNotHighlighter() {
        manager.selectedTool = .pen
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        XCTAssertFalse(manager.strokes[0].isHighlighter)
    }

    func testHighlighterTool_isHighlighter() {
        manager.selectedTool = .highlighter
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        XCTAssertTrue(manager.strokes[0].isHighlighter)
    }

    func testHighlighterTool_widerThanPen() {
        manager.lineWidth = 3

        manager.selectedTool = .pen
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        let penWidth = manager.strokes[0].lineWidth
        manager.clearAll()

        manager.selectedTool = .highlighter
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        let highlighterWidth = manager.strokes[0].lineWidth
        XCTAssertGreaterThan(highlighterWidth, penWidth)
    }

    // MARK: - clearAll

    func testClearAll_removesAllStrokes() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        manager.endStroke()
        manager.beginStroke(at: CGPoint(x: 5, y: 5))
        manager.continueStroke(at: CGPoint(x: 6, y: 6))
        manager.endStroke()

        manager.clearAll()
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    func testClearAll_whileMidStroke_clearsEverything() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        // Did not call endStroke
        manager.clearAll()
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    // MARK: - undoLast

    func testUndoLast_removesLastStroke() {
        manager.beginStroke(at: .zero)
        manager.continueStroke(at: CGPoint(x: 1, y: 1))
        manager.endStroke()
        manager.beginStroke(at: CGPoint(x: 10, y: 10))
        manager.continueStroke(at: CGPoint(x: 11, y: 11))
        manager.endStroke()

        manager.undoLast()
        XCTAssertEqual(manager.strokes.count, 1)
    }

    func testUndoLast_onEmpty_doesNotCrash() {
        manager.undoLast()
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    func testUndoLast_multipleUndos_goesToEmpty() {
        for i in 0..<3 {
            manager.beginStroke(at: CGPoint(x: Double(i), y: 0))
            manager.continueStroke(at: CGPoint(x: Double(i) + 1, y: 1))
            manager.endStroke()
        }
        manager.undoLast()
        manager.undoLast()
        manager.undoLast()
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    // MARK: - eraseNear

    func testEraseNear_removesStrokeWithinRadius() {
        manager.beginStroke(at: CGPoint(x: 5, y: 5))
        manager.continueStroke(at: CGPoint(x: 6, y: 6))
        manager.endStroke()

        manager.eraseNear(CGPoint(x: 5, y: 5), radius: 20)
        XCTAssertTrue(manager.strokes.isEmpty)
    }

    func testEraseNear_doesNotRemoveDistantStroke() {
        manager.beginStroke(at: CGPoint(x: 200, y: 200))
        manager.continueStroke(at: CGPoint(x: 201, y: 201))
        manager.endStroke()

        manager.eraseNear(CGPoint(x: 0, y: 0), radius: 20)
        XCTAssertEqual(manager.strokes.count, 1)
    }
}
