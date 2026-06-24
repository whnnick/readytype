import XCTest
@testable import ReadyType

@MainActor
final class VoiceInputControllerTests: XCTestCase {
    func testBeginRecordingChecksPermissionsAndStartsRecorder() async throws {
        let appState = AppState()
        let recorder = MockAudioRecordingManaging(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1))
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .granted },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: MockSpeechTranscribing(transcript: "hello"),
            transcriptHandler: MockTranscriptHandling()
        )

        try await controller.beginRecording()

        XCTAssertEqual(recorder.startCount, 1)
        XCTAssertEqual(appState.runtimeState, .recording)
    }

    func testBeginRecordingRequestsUndeterminedPermissionsBeforeRecording() async throws {
        let appState = AppState()
        let recorder = MockAudioRecordingManaging(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1))
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .notDetermined },
                speechRecognitionStatus: { .notDetermined },
                accessibilityStatus: { .granted },
                requestMicrophonePermission: { .granted },
                requestSpeechRecognitionPermission: { .granted }
            ),
            recorder: recorder,
            transcriber: MockSpeechTranscribing(transcript: "hello"),
            transcriptHandler: MockTranscriptHandling()
        )

        try await controller.beginRecording()

        XCTAssertEqual(recorder.startCount, 1)
        XCTAssertEqual(appState.runtimeState, .recording)
    }

    func testBeginRecordingClearsPreviousVocabularySuggestions() async throws {
        let appState = AppState(
            userVocabularySuggestions: [
                UserVocabularySuggestion(
                    value: "ReadyType",
                    kind: .product,
                    aliases: ["ReadyTap"],
                    reason: "刚才可能想保留这个词"
                )
            ]
        )
        let recorder = MockAudioRecordingManaging(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1))
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .granted },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: MockSpeechTranscribing(transcript: "hello"),
            transcriptHandler: MockTranscriptHandling()
        )

        try await controller.beginRecording()

        XCTAssertTrue(appState.userVocabularySuggestions.isEmpty)
    }

    func testBeginRecordingThrowsWhenMicrophoneMissing() async {
        let appState = AppState()
        let recorder = MockAudioRecordingManaging(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1))
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .denied },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: MockSpeechTranscribing(transcript: "hello"),
            transcriptHandler: MockTranscriptHandling()
        )

        do {
            try await controller.beginRecording()
            XCTFail("Expected microphonePermissionMissing")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .microphonePermissionMissing)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(recorder.startCount, 0)
        XCTAssertEqual(appState.runtimeState, .error("需要麦克风权限才能语音输入。"))
    }

    func testFinishRecordingStopsTranscribesAndHandlesTranscript() async throws {
        let appState = AppState()
        let recording = AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1.4)
        let recorder = MockAudioRecordingManaging(recording: recording)
        let transcriber = MockSpeechTranscribing(transcript: "recognized words")
        let transcriptHandler = MockTranscriptHandling()
        var dates = [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 100.2),
            Date(timeIntervalSince1970: 102),
            Date(timeIntervalSince1970: 103.25)
        ]
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .granted },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: transcriber,
            transcriptHandler: transcriptHandler,
            now: { dates.removeFirst() }
        )

        try await controller.beginRecording()
        try await controller.finishRecording()

        XCTAssertEqual(recorder.stopCount, 1)
        XCTAssertEqual(transcriber.recordings, [recording])
        XCTAssertEqual(transcriptHandler.transcripts, ["recognized words"])
        XCTAssertEqual(appState.lastVoiceRunMetrics?.recordingDuration, 1.4)
        XCTAssertEqual(appState.lastVoiceRunMetrics?.inputFeedbackLatencyMilliseconds, 200)
        XCTAssertEqual(appState.lastVoiceRunMetrics?.firstPreviewLatencyMilliseconds, 3_250)
        XCTAssertEqual(appState.lastVoiceRunMetrics?.transcriptionLatencyMilliseconds, 1_250)
    }

    func testCancelRecordingStopsRecorderWithoutTranscribing() async throws {
        let appState = AppState()
        let recorder = MockAudioRecordingManaging(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 1.4))
        let transcriber = MockSpeechTranscribing(transcript: "recognized words")
        let transcriptHandler = MockTranscriptHandling()
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .granted },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: transcriber,
            transcriptHandler: transcriptHandler
        )

        try await controller.beginRecording()
        controller.cancelRecording()

        XCTAssertEqual(recorder.cancelCount, 1)
        XCTAssertEqual(recorder.stopCount, 0)
        XCTAssertTrue(transcriber.recordings.isEmpty)
        XCTAssertTrue(transcriptHandler.transcripts.isEmpty)
        XCTAssertEqual(appState.runtimeState, .idle)
        XCTAssertEqual(appState.lastMessage, "已取消本次输入")
        XCTAssertNil(appState.lastVoiceRunMetrics)
    }

    func testFinishRecordingErrorUpdatesAppState() async {
        let appState = AppState()
        let recorder = MockAudioRecordingManaging(error: ReadyTypeError.recordingTooShort)
        let controller = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(
                microphoneStatus: { .granted },
                speechRecognitionStatus: { .granted },
                accessibilityStatus: { .granted }
            ),
            recorder: recorder,
            transcriber: MockSpeechTranscribing(transcript: "recognized words"),
            transcriptHandler: MockTranscriptHandling()
        )

        do {
            try await controller.finishRecording()
            XCTFail("Expected recordingTooShort")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .recordingTooShort)
            XCTAssertEqual(appState.runtimeState, .error("语音太短，已忽略。"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockAudioRecordingManaging: AudioRecordingManaging {
    private let recording: AudioRecording?
    private let error: Error?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0

    init(recording: AudioRecording) {
        self.recording = recording
        self.error = nil
    }

    init(error: Error) {
        self.recording = nil
        self.error = error
    }

    @discardableResult
    func startRecording() throws -> URL {
        startCount += 1
        return recording?.fileURL ?? URL(fileURLWithPath: "/tmp/test.m4a")
    }

    func stopRecording() throws -> AudioRecording {
        stopCount += 1

        if let error {
            throw error
        }

        return recording!
    }

    func cancelRecording() {
        cancelCount += 1
    }
}

private final class MockSpeechTranscribing: SpeechTranscribing {
    private let transcript: String
    private(set) var recordings: [AudioRecording] = []

    init(transcript: String) {
        self.transcript = transcript
    }

    func transcribe(recording: AudioRecording) async throws -> String {
        recordings.append(recording)
        return transcript
    }
}

private final class MockTranscriptHandling: TranscriptHandling {
    private(set) var transcripts: [String] = []

    func handleTranscript(_ transcript: String) async throws {
        transcripts.append(transcript)
    }
}
