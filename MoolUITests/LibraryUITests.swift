import AVFoundation
import CoreVideo
import Foundation
import XCTest

final class LibraryUITests: XCTestCase {
    private static let appBundleIdentifier = "com.mool.app"
    private let sampleRecordingName = "UITestSample"
    private var storageDirectoryURL: URL!
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        try terminateRunningMoolInstances()
        storageDirectoryURL = makeStorageDirectory()
        try createSampleRecording(named: sampleRecordingName, in: storageDirectoryURL)
        app = XCUIApplication()
        app.launchArguments += ["UITEST_OPEN_LIBRARY"]
        app.launchEnvironment["MOOL_TEST_STORAGE_PATH"] = storageDirectoryURL.path
        app.launch()
        app.activate()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        if let storageDirectoryURL {
            try? FileManager.default.removeItem(at: storageDirectoryURL)
        }
        storageDirectoryURL = nil
    }

    // MARK: - Tests

    func testOpenLibrary_windowAppears() {
        let window = app.windows.firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 8))
    }

    func testLibrary_showsContent() {
        let window = app.windows.firstMatch
        guard window.waitForExistence(timeout: 8) else {
            XCTFail("Library window did not appear")
            return
        }

        // Depending on local files, library can show an empty state or a recordings list.
        let emptyState = window.staticTexts["No Recordings Yet"]
        let recordingsList = window.tables.firstMatch
        XCTAssertTrue(emptyState.waitForExistence(timeout: 2) || recordingsList.exists)
    }

    func testEditTrimEndHandle_dragsAndUpdatesEndLabel() {
        openEditorForSampleRecording()

        let endLabel = app.staticTexts["library.trim.end"].firstMatch
        XCTAssertTrue(endLabel.waitForExistence(timeout: 8), "Trim end label did not appear")
        let initialEndLabel = displayedText(of: endLabel)

        let endHandle = app.descendants(matching: .any)["library.trimHandle.end"].firstMatch
        XCTAssertTrue(endHandle.waitForExistence(timeout: 8), "Trim end handle did not appear")

        let dragStart = endHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = endHandle.coordinate(withNormalizedOffset: CGVector(dx: -2.0, dy: 0.5))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        XCTAssertTrue(
            waitForElementText(endLabel, differsFrom: initialEndLabel, timeout: 5),
            "End trim label did not change after dragging the end handle. Initial text: \(initialEndLabel)"
        )
    }

    func testEditTrimStartHandle_dragsAndUpdatesStartLabel() {
        openEditorForSampleRecording()

        let startLabel = app.staticTexts["library.trim.start"].firstMatch
        XCTAssertTrue(startLabel.waitForExistence(timeout: 8), "Trim start label did not appear")
        let initialStartLabel = displayedText(of: startLabel)

        let startHandle = app.descendants(matching: .any)["library.trimHandle.start"].firstMatch
        XCTAssertTrue(startHandle.waitForExistence(timeout: 8), "Trim start handle did not appear")

        let dragStart = startHandle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dragEnd = startHandle.coordinate(withNormalizedOffset: CGVector(dx: 3.0, dy: 0.5))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        XCTAssertTrue(
            waitForElementText(startLabel, differsFrom: initialStartLabel, timeout: 5),
            "Start trim label did not change after dragging the start handle. Initial text: \(initialStartLabel)"
        )
    }

    private func makeStorageDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("mool-library-uitests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func createSampleRecording(named name: String, in directory: URL) throws {
        let url = directory.appendingPathComponent(name).appendingPathExtension("mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 320,
            AVVideoHeightKey: 180
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: 320,
                kCVPixelBufferHeightKey as String: 180
            ]
        )

        XCTAssertTrue(writer.canAdd(input))
        writer.add(input)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        let frameCount = 60
        let timescale: Int32 = 10

        for frame in 0 ..< frameCount {
            while !input.isReadyForMoreMediaData {
                RunLoop.current.run(until: Date().addingTimeInterval(0.01))
            }

            guard let buffer = makePixelBuffer(width: 320, height: 180, value: UInt8((frame * 3) % 255)) else {
                XCTFail("Failed to allocate pixel buffer for sample recording")
                return
            }

            let time = CMTime(value: Int64(frame), timescale: timescale)
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: time))
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 10)

        XCTAssertEqual(writer.status, .completed, "Sample recording creation failed: \(writer.error?.localizedDescription ?? "unknown")")
    }

    private func makePixelBuffer(width: Int, height: Int, value: UInt8) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            nil,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true, kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0 ..< height {
            memset(baseAddress.advanced(by: row * bytesPerRow), Int32(value), bytesPerRow)
        }
        return buffer
    }

    private func waitForElementText(
        _ element: XCUIElement,
        differsFrom previousText: String,
        timeout: TimeInterval = 5
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, displayedText(of: element) != previousText {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return false
    }

    private func displayedText(of element: XCUIElement) -> String {
        if !element.label.isEmpty {
            return element.label
        }

        if let value = element.value as? String {
            return value
        }

        return ""
    }

    private func openEditorForSampleRecording() {
        let window = app.windows.matching(NSPredicate(format: "title == %@", "Library")).firstMatch
        XCTAssertTrue(window.waitForExistence(timeout: 8), "Library window did not appear")

        let recordingRow = app.descendants(matching: .any)["library.recording.\(sampleRecordingName)"].firstMatch
        XCTAssertTrue(recordingRow.waitForExistence(timeout: 8), "Sample recording row did not appear")
        click(recordingRow)

        let editButton = app.buttons["Edit"].firstMatch
        XCTAssertTrue(editButton.waitForExistence(timeout: 8), "Edit button did not appear")
        click(editButton)
    }

    private func click(_ element: XCUIElement) {
        if element.isHittable {
            element.click()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        }
    }

    private func terminateRunningMoolInstances() throws {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Self.appBundleIdentifier)
            if runningApps.isEmpty { return }
            for runningApp in runningApps {
                if !runningApp.terminate() {
                    _ = runningApp.forceTerminate()
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }
}
