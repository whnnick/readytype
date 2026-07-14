import XCTest
@testable import ReadyType

final class AudioRecorderServiceTests: XCTestCase {
    func testStartRecordingCreatesFileURLAndStartsBackend() throws {
        let backend = MockAudioRecorderBackend()
        let service = AudioRecorderService(
            backend: backend,
            now: { Date(timeIntervalSince1970: 100) },
            fileURLProvider: { URL(fileURLWithPath: "/tmp/test-recording.m4a") }
        )

        let url = try service.startRecording()

        XCTAssertEqual(url.path, "/tmp/test-recording.m4a")
        XCTAssertEqual(backend.startedURLs, [url])
    }

    func testStopRecordingReturnsRecordingWhenDurationIsLongEnough() throws {
        var currentTime = Date(timeIntervalSince1970: 100)
        let backend = MockAudioRecorderBackend()
        let service = AudioRecorderService(
            backend: backend,
            minimumDuration: 0.3,
            now: { currentTime },
            fileURLProvider: { URL(fileURLWithPath: "/tmp/test-recording.m4a") }
        )

        let url = try service.startRecording()
        currentTime = Date(timeIntervalSince1970: 100.75)

        let recording = try service.stopRecording()

        XCTAssertEqual(recording.fileURL, url)
        XCTAssertEqual(recording.duration, 0.75, accuracy: 0.001)
        XCTAssertEqual(backend.stopCount, 1)
    }

    func testStopRecordingThrowsWhenRecordingIsTooShort() throws {
        var currentTime = Date(timeIntervalSince1970: 100)
        let backend = MockAudioRecorderBackend()
        let service = AudioRecorderService(
            backend: backend,
            minimumDuration: 0.3,
            now: { currentTime },
            fileURLProvider: { URL(fileURLWithPath: "/tmp/test-recording.m4a") }
        )

        _ = try service.startRecording()
        currentTime = Date(timeIntervalSince1970: 100.1)

        XCTAssertThrowsError(try service.stopRecording()) { error in
            XCTAssertEqual(error as? ReadyTypeError, .recordingTooShort)
        }
        XCTAssertEqual(backend.stopCount, 1)
    }

    func testStopRecordingWithoutActiveRecordingThrowsRecordingFailed() {
        let service = AudioRecorderService(backend: MockAudioRecorderBackend())

        XCTAssertThrowsError(try service.stopRecording()) { error in
            XCTAssertEqual(error as? ReadyTypeError, .recordingFailed("No active recording."))
        }
    }

    func testCancelRecordingStopsBackendAndClearsActiveRecording() throws {
        let backend = MockAudioRecorderBackend()
        let service = AudioRecorderService(
            backend: backend,
            now: { Date(timeIntervalSince1970: 100) },
            fileURLProvider: { URL(fileURLWithPath: "/tmp/test-recording.m4a") }
        )

        _ = try service.startRecording()
        service.cancelRecording()

        XCTAssertEqual(backend.stopCount, 1)
        XCTAssertThrowsError(try service.stopRecording()) { error in
            XCTAssertEqual(error as? ReadyTypeError, .recordingFailed("No active recording."))
        }
    }

    func testCurrentLevelUsesActiveRecorderPower() throws {
        let backend = MockAudioRecorderBackend()
        backend.currentPower = -27
        let service = AudioRecorderService(
            backend: backend,
            fileURLProvider: { URL(fileURLWithPath: "/tmp/test-recording.m4a") }
        )

        XCTAssertEqual(service.currentLevel(), 0)

        try service.startRecording()

        XCTAssertEqual(service.currentLevel(), 0.5, accuracy: 0.001)
    }

    func testAudioLevelNormalizerClampsSilenceAndLoudInput() {
        XCTAssertEqual(AudioLevelNormalizer.normalize(decibels: -160), 0)
        XCTAssertEqual(AudioLevelNormalizer.normalize(decibels: -48), 0)
        XCTAssertEqual(AudioLevelNormalizer.normalize(decibels: -6), 1)
        XCTAssertEqual(AudioLevelNormalizer.normalize(decibels: 0), 1)
    }
}

private final class MockAudioRecorderBackend: AudioRecorderBackend {
    private(set) var startedURLs: [URL] = []
    private(set) var stopCount = 0
    var currentPower: Float?

    func startRecording(to fileURL: URL) throws {
        startedURLs.append(fileURL)
    }

    func stopRecording() {
        stopCount += 1
    }

    func currentPowerLevel() -> Float? {
        currentPower
    }
}
