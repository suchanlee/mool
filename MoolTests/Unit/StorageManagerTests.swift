import XCTest
@testable import Mool

@MainActor
final class StorageManagerTests: XCTestCase {

    var storageManager: StorageManager!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        // Create a fresh temp directory for each test
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MoolTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        storageManager = StorageManager()
        storageManager.setStoragePath(tempDir)
        // Explicitly refresh so tests see the current state of tempDir
        await storageManager.refresh()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        storageManager = nil
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - newRecordingURL

    func testNewRecordingURL_matchesExpectedPattern() {
        let url = storageManager.newRecordingURL()
        let name = url.lastPathComponent
        let pattern = #"^Mool_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}\.mov$"#
        let range = name.range(of: pattern, options: .regularExpression)
        XCTAssertNotNil(range, "Filename '\(name)' did not match expected pattern '\(pattern)'")
    }

    func testNewRecordingURL_parentDirectoryIsStoragePath() {
        let url = storageManager.newRecordingURL()
        XCTAssertEqual(url.deletingLastPathComponent(), tempDir)
    }

    func testNewRecordingURL_extensionIsMov() {
        let url = storageManager.newRecordingURL()
        XCTAssertEqual(url.pathExtension, "mov")
    }

    func testNewRecordingURL_consecutiveCallsReturnSameOrDifferent() {
        // Both calls happen within the same second, so the filenames may be equal.
        // The important thing is that they are well-formed URLs in the storage path.
        let url1 = storageManager.newRecordingURL()
        let url2 = storageManager.newRecordingURL()
        XCTAssertEqual(url1.deletingLastPathComponent(), url2.deletingLastPathComponent())
    }

    // MARK: - refresh

    func testRefresh_emptyDirectory_recordingsIsEmpty() async {
        await storageManager.refresh()
        XCTAssertTrue(storageManager.recordings.isEmpty)
    }

    func testRefresh_withMovFile_countIsOne() async throws {
        let fileURL = tempDir.appendingPathComponent("test.mov")
        try Data().write(to: fileURL)
        await storageManager.refresh()
        XCTAssertEqual(storageManager.recordings.count, 1)
    }

    func testRefresh_ignoresPngFiles() async throws {
        let pngURL = tempDir.appendingPathComponent("screenshot.png")
        try Data().write(to: pngURL)
        await storageManager.refresh()
        XCTAssertTrue(storageManager.recordings.isEmpty)
    }

    func testRefresh_countsMp4Files() async throws {
        let mp4URL = tempDir.appendingPathComponent("clip.mp4")
        try Data().write(to: mp4URL)
        await storageManager.refresh()
        XCTAssertEqual(storageManager.recordings.count, 1)
    }

    func testRefresh_multipleVideoFiles_allCounted() async throws {
        try Data().write(to: tempDir.appendingPathComponent("a.mov"))
        try Data().write(to: tempDir.appendingPathComponent("b.mp4"))
        try Data().write(to: tempDir.appendingPathComponent("c.png"))  // ignored
        await storageManager.refresh()
        XCTAssertEqual(storageManager.recordings.count, 2)
    }

    // MARK: - delete

    func testDelete_removesRecordingFromList() async throws {
        let fileURL = tempDir.appendingPathComponent("recording.mov")
        try Data().write(to: fileURL)
        await storageManager.refresh()
        XCTAssertEqual(storageManager.recordings.count, 1)

        let recording = storageManager.recordings[0]
        try storageManager.delete(recording)
        XCTAssertTrue(storageManager.recordings.isEmpty)
    }
}
