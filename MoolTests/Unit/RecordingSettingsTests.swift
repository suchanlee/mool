import XCTest
@testable import Mool

final class RecordingSettingsTests: XCTestCase {

    private let defaultsKey = "MoolRecordingSettings"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    // MARK: - Default values

    func testDefaultMode() {
        XCTAssertEqual(RecordingSettings().mode, .screenAndCamera)
    }

    func testDefaultQuality() {
        XCTAssertEqual(RecordingSettings().quality, .hd1080)
    }

    func testDefaultCountdown() {
        XCTAssertEqual(RecordingSettings().countdownDuration, 3)
    }

    func testDefaultAudioFlags() {
        let s = RecordingSettings()
        XCTAssertTrue(s.captureMicrophone)
        XCTAssertTrue(s.captureSystemAudio)
        XCTAssertFalse(s.mirrorCamera)
        XCTAssertFalse(s.launchAtLogin)
    }

    // MARK: - Save / Load round-trip

    func testSaveAndLoad_mode() {
        let s = RecordingSettings()
        s.mode = .cameraOnly
        s.save()
        XCTAssertEqual(RecordingSettings().mode, .cameraOnly)
    }

    func testSaveAndLoad_quality() {
        let s = RecordingSettings()
        s.quality = .hd720
        s.save()
        XCTAssertEqual(RecordingSettings().quality, .hd720)
    }

    func testSaveAndLoad_countdown() {
        let s = RecordingSettings()
        s.countdownDuration = 7
        s.save()
        XCTAssertEqual(RecordingSettings().countdownDuration, 7)
    }

    func testSaveAndLoad_audioFlags() {
        let s = RecordingSettings()
        s.captureMicrophone = false
        s.captureSystemAudio = false
        s.mirrorCamera = true
        s.launchAtLogin = true
        s.save()

        let loaded = RecordingSettings()
        XCTAssertFalse(loaded.captureMicrophone)
        XCTAssertFalse(loaded.captureSystemAudio)
        XCTAssertTrue(loaded.mirrorCamera)
        XCTAssertTrue(loaded.launchAtLogin)
    }

    func testSaveAndLoad_storagePath() {
        let s = RecordingSettings()
        let testURL = URL(fileURLWithPath: "/tmp/mool-unit-test")
        s.storagePath = testURL
        s.save()
        XCTAssertEqual(RecordingSettings().storagePath, testURL)
    }

    func testSaveAndLoad_selectedInputDeviceIDs() {
        let s = RecordingSettings()
        s.selectedCameraUniqueID = "camera-123"
        s.selectedMicrophoneUniqueID = "mic-456"
        s.save()

        let loaded = RecordingSettings()
        XCTAssertEqual(loaded.selectedCameraUniqueID, "camera-123")
        XCTAssertEqual(loaded.selectedMicrophoneUniqueID, "mic-456")
    }

    // MARK: - Runtime-only properties are not persisted

    func testRuntimePropertiesNotPersisted() {
        let s = RecordingSettings()
        s.selectedDisplayIndex = 5
        s.selectedWindowID = 99999
        s.save()

        let loaded = RecordingSettings()
        XCTAssertEqual(loaded.selectedDisplayIndex, 0)
        XCTAssertNil(loaded.selectedWindowID)
    }

    // MARK: - RecordingMode

    func testScreenAndCamera_includesBoth() {
        XCTAssertTrue(RecordingMode.screenAndCamera.includesScreen)
        XCTAssertTrue(RecordingMode.screenAndCamera.includesCamera)
    }

    func testScreenOnly_doesNotIncludeCamera() {
        XCTAssertTrue(RecordingMode.screenOnly.includesScreen)
        XCTAssertFalse(RecordingMode.screenOnly.includesCamera)
    }

    func testCameraOnly_doesNotIncludeScreen() {
        XCTAssertFalse(RecordingMode.cameraOnly.includesScreen)
        XCTAssertTrue(RecordingMode.cameraOnly.includesCamera)
    }

    func testAllModesCodable() throws {
        for mode in RecordingMode.allCases {
            let data = try JSONEncoder().encode(mode)
            let decoded = try JSONDecoder().decode(RecordingMode.self, from: data)
            XCTAssertEqual(decoded, mode, "Codable round-trip failed for \(mode)")
        }
    }

    // MARK: - VideoQuality

    func testQualityResolutions() {
        XCTAssertEqual(VideoQuality.hd720.resolution, CGSize(width: 1280, height: 720))
        XCTAssertEqual(VideoQuality.hd1080.resolution, CGSize(width: 1920, height: 1080))
        XCTAssertEqual(VideoQuality.uhd4k.resolution, CGSize(width: 3840, height: 2160))
    }

    func testQualityBitratesIncreaseWithResolution() {
        XCTAssertLessThan(VideoQuality.hd720.videoBitrate, VideoQuality.hd1080.videoBitrate)
        XCTAssertLessThan(VideoQuality.hd1080.videoBitrate, VideoQuality.uhd4k.videoBitrate)
    }

    func testAllQualitiesCodable() throws {
        for quality in VideoQuality.allCases {
            let data = try JSONEncoder().encode(quality)
            let decoded = try JSONDecoder().decode(VideoQuality.self, from: data)
            XCTAssertEqual(decoded, quality, "Codable round-trip failed for \(quality)")
        }
    }
}
