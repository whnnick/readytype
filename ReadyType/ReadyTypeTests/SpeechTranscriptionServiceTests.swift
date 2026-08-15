import XCTest
import Speech
@testable import ReadyType

@MainActor
final class SpeechTranscriptionServiceTests: XCTestCase {
    func testTranscribeReturnsTrimmedTranscript() async throws {
        let backend = MockSpeechRecognitionBackend(result: "  recognized text  ")
        let service = SpeechTranscriptionService(backend: backend)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await service.transcribe(recording: AudioRecording(fileURL: url, duration: 1.2))

        XCTAssertEqual(transcript, "recognized text")
        XCTAssertEqual(backend.requestedURLs, [url])
    }

    func testTranscribeThrowsWhenBackendReturnsEmptyTranscript() async {
        let backend = MockSpeechRecognitionBackend(result: "   ")
        let service = SpeechTranscriptionService(backend: backend)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        do {
            _ = try await service.transcribe(recording: AudioRecording(fileURL: url, duration: 1.2))
            XCTFail("Expected transcriptionEmpty")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .transcriptionEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeMapsUnexpectedBackendError() async {
        let backend = MockSpeechRecognitionBackend(error: NSError(domain: "Speech", code: 42))
        let service = SpeechTranscriptionService(backend: backend)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        do {
            _ = try await service.transcribe(recording: AudioRecording(fileURL: url, duration: 1.2))
            XCTFail("Expected transcriptionFailed")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .transcriptionFailed("Speech error 42"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeRejectsRepeatedLongHallucination() async {
        let phrase = "请不吝点赞、订阅、转发、打赏支持明镜与点点栏目。"
        let backend = MockSpeechRecognitionBackend(result: phrase + phrase)
        let service = SpeechTranscriptionService(backend: backend)

        do {
            _ = try await service.transcribe(
                recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 4)
            )
            XCTFail("Expected transcriptionEmpty")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .transcriptionEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeKeepsNaturalShortRepetition() async throws {
        let backend = MockSpeechRecognitionBackend(result: "好好学习，天天向上。")
        let service = SpeechTranscriptionService(backend: backend)

        let transcript = try await service.transcribe(
            recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 2)
        )

        XCTAssertEqual(transcript, "好好学习，天天向上。")
    }

    func testRoutedBackendAutomaticShortInputUsesFastSystemEvenWhenHighAccuracyIsReady() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(result: "high accuracy text")
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .automatic,
                    scenario: .message,
                    frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: []
                )
            }
        )
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribe(recording: AudioRecording(fileURL: url, duration: 3))

        XCTAssertEqual(transcript, "fast text")
        XCTAssertEqual(fastBackend.requestedURLs, [url])
        XCTAssertTrue(highAccuracyBackend.requestedURLs.isEmpty)
    }

    func testRoutedBackendStartsFastAndHighAccuracyTogetherButPrefersHighAccuracyWithinBudget() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast text")
        let highAccuracyBackend = MockCandidateSpeechRecognitionBackend(
            candidate: SpeechRecognitionCandidate(
                transcript: "high accuracy text",
                quality: .whisper(
                    averageLogProbability: -0.2,
                    maximumNoSpeechProbability: 0.1,
                    maximumCompressionRatio: 1.2
                )
            ),
            delay: .milliseconds(20)
        )
        var routeDecisions: [SpeechRecognitionRouteDecision] = []
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .automatic,
                    scenario: .document,
                    frontmostAppBundleIdentifier: "md.obsidian",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: ["ReadyType"]
                )
            },
            onDecision: { decision in
                routeDecisions.append(decision)
            }
        )
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribe(recording: AudioRecording(fileURL: url, duration: 18))

        XCTAssertEqual(transcript, "high accuracy text")
        XCTAssertEqual(highAccuracyBackend.requestedURLs, [url])
        XCTAssertEqual(highAccuracyBackend.requestedContextualTerms, [["ReadyType"]])
        XCTAssertEqual(fastBackend.requestedURLs, [url])
        XCTAssertEqual(routeDecisions, [SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil)])
    }

    func testCandidateSelectorPrefersFastWhenHighAccuracyHasNoQualityAdvantage() {
        let selector = SpeechRecognitionCandidateSelector()
        let fast = SpeechRecognitionCandidate(transcript: "fast text")
        let high = SpeechRecognitionCandidate(transcript: "high text")

        let selection = selector.select(fastSystem: fast, highAccuracy: high, deadlineReached: false)

        XCTAssertEqual(
            selection,
            SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: fast)
        )
    }

    func testCandidateSelectorRejectsRepeatedHighAccuracyHallucination() {
        let selector = SpeechRecognitionCandidateSelector()
        let fast = SpeechRecognitionCandidate(
            transcript: "这是正常的识别结果。",
            quality: .system(averageSegmentConfidence: 0.8)
        )
        let phrase = "请不吝点赞、订阅、转发、打赏支持明镜与点点栏目。"
        let high = SpeechRecognitionCandidate(
            transcript: phrase + phrase,
            quality: .whisper(
                averageLogProbability: -0.2,
                maximumNoSpeechProbability: 0.1,
                maximumCompressionRatio: 1.2
            )
        )

        let selection = selector.select(fastSystem: fast, highAccuracy: high, deadlineReached: false)

        XCTAssertEqual(
            selection,
            SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: fast)
        )
    }

    func testCandidateSelectorPrefersHighAccuracyWhenSystemConfidenceIsLow() {
        let selector = SpeechRecognitionCandidateSelector()
        let fast = SpeechRecognitionCandidate(
            transcript: "fast text",
            quality: .system(averageSegmentConfidence: 0.45)
        )
        let high = SpeechRecognitionCandidate(
            transcript: "high text",
            quality: .whisper(
                averageLogProbability: -0.7,
                maximumNoSpeechProbability: 0.2,
                maximumCompressionRatio: 1.5
            )
        )

        let selection = selector.select(fastSystem: fast, highAccuracy: high, deadlineReached: false)

        XCTAssertEqual(
            selection,
            SpeechRecognitionCandidateSelection(backend: .highAccuracyLocal, candidate: high)
        )
    }

    func testCandidateSelectorWaitsForSecondCandidateUntilDeadline() {
        let selector = SpeechRecognitionCandidateSelector()
        let fast = SpeechRecognitionCandidate(transcript: "fast text")

        XCTAssertNil(selector.select(fastSystem: fast, highAccuracy: nil, deadlineReached: false))
        XCTAssertEqual(
            selector.select(fastSystem: fast, highAccuracy: nil, deadlineReached: true),
            SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: fast)
        )
    }

    func testCandidateSelectorRejectsLowQualityWhisperCandidate() {
        let selector = SpeechRecognitionCandidateSelector()
        let fast = SpeechRecognitionCandidate(
            transcript: "fast text",
            quality: .system(averageSegmentConfidence: 0.8)
        )
        let high = SpeechRecognitionCandidate(
            transcript: "high text",
            quality: .whisper(
                averageLogProbability: -1.2,
                maximumNoSpeechProbability: 0.8,
                maximumCompressionRatio: 2.8
            )
        )

        let selection = selector.select(fastSystem: fast, highAccuracy: high, deadlineReached: false)

        XCTAssertEqual(
            selection,
            SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: fast)
        )
    }

    func testQualityEvidenceFactoryAggregatesEngineNativeSignals() {
        XCTAssertEqual(
            SpeechRecognitionQualityEvidenceFactory.systemAverageConfidence([0, 0.6, 0.8]) ?? -1,
            0.7,
            accuracy: 0.0001
        )
        XCTAssertNil(SpeechRecognitionQualityEvidenceFactory.systemAverageConfidence([0, 0]))

        let quality = SpeechRecognitionQualityEvidenceFactory.whisper(
            segments: [
                WhisperSegmentQuality(
                    duration: 1,
                    averageLogProbability: -0.2,
                    noSpeechProbability: 0.1,
                    compressionRatio: 1.2
                ),
                WhisperSegmentQuality(
                    duration: 3,
                    averageLogProbability: -0.6,
                    noSpeechProbability: 0.4,
                    compressionRatio: 1.7
                )
            ]
        )

        guard case let .whisper(averageLogProbability, noSpeechProbability, compressionRatio) = quality else {
            return XCTFail("Expected Whisper quality evidence")
        }
        XCTAssertEqual(averageLogProbability, -0.5, accuracy: 0.0001)
        XCTAssertEqual(noSpeechProbability, 0.4, accuracy: 0.0001)
        XCTAssertEqual(compressionRatio, 1.7, accuracy: 0.0001)
        XCTAssertEqual(SpeechRecognitionQualityEvidenceFactory.whisper(segments: []), .unavailable)
    }

    func testCandidateSelectorUsesStructurallyValidFastResultAtDeadline() {
        let selector = SpeechRecognitionCandidateSelector()
        let lowConfidenceFast = SpeechRecognitionCandidate(
            transcript: "仍然可用的极速结果",
            quality: .system(averageSegmentConfidence: 0.2)
        )

        XCTAssertEqual(
            selector.select(fastSystem: lowConfidenceFast, highAccuracy: nil, deadlineReached: true),
            SpeechRecognitionCandidateSelection(backend: .fastSystem, candidate: lowConfidenceFast)
        )
    }

    func testRoutedBackendFallsBackToFastSystemWhenSelectedHighAccuracyFails() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast fallback text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(error: ReadyTypeError.transcriptionFailed("high accuracy failed"))
        var routeDecisions: [SpeechRecognitionRouteDecision] = []
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .highAccuracyLocal,
                    scenario: .document,
                    frontmostAppBundleIdentifier: "md.obsidian",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: ["ReadyType"]
                )
            },
            onDecision: { decision in
                routeDecisions.append(decision)
            }
        )
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribe(recording: AudioRecording(fileURL: url, duration: 18))

        XCTAssertEqual(transcript, "fast fallback text")
        XCTAssertEqual(highAccuracyBackend.requestedURLs, [url])
        XCTAssertEqual(fastBackend.requestedURLs, [url])
        XCTAssertEqual(
            routeDecisions,
            [
                SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil),
                SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: "高精度识别失败，已使用极速识别。")
            ]
        )
    }

    func testRoutedBackendFallsBackToFastSystemWhenAutomaticHighAccuracyTimesOut() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast fallback text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(result: "late high accuracy text", delay: .milliseconds(200))
        var routeDecisions: [SpeechRecognitionRouteDecision] = []
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .automatic,
                    scenario: .document,
                    frontmostAppBundleIdentifier: "md.obsidian",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: ["ReadyType"]
                )
            },
            onDecision: { decision in
                routeDecisions.append(decision)
            },
            automaticHighAccuracyTimeout: .milliseconds(10)
        )
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribe(recording: AudioRecording(fileURL: url, duration: 18))

        XCTAssertEqual(transcript, "fast fallback text")
        XCTAssertEqual(highAccuracyBackend.requestedURLs, [url])
        XCTAssertEqual(fastBackend.requestedURLs, [url])
        XCTAssertEqual(
            routeDecisions,
            [
                SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil),
                SpeechRecognitionRouteDecision(backend: .fastSystem, fallbackReason: "高精度识别等待过久，已使用极速识别。")
            ]
        )
    }

    func testRoutedBackendDoesNotTimeoutExplicitHighAccuracySelection() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast fallback text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(result: "high accuracy text", delay: .milliseconds(30))
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .highAccuracyLocal,
                    scenario: .document,
                    frontmostAppBundleIdentifier: "md.obsidian",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: []
                )
            },
            automaticHighAccuracyTimeout: .milliseconds(1)
        )
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribe(recording: AudioRecording(fileURL: url, duration: 18))

        XCTAssertEqual(transcript, "high accuracy text")
        XCTAssertEqual(highAccuracyBackend.requestedURLs, [url])
        XCTAssertTrue(fastBackend.requestedURLs.isEmpty)
    }

    func testRoutedBackendPassesCappedContextualTermsToFastSystemBackend() async throws {
        let terms = (0..<120).map { "Term\($0)" }
        let fastBackend = MockContextualSpeechRecognitionBackend(result: "fast text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(result: "high accuracy text")
        let backend = RoutedSpeechRecognitionBackend(
            fastSystemBackend: fastBackend,
            highAccuracyBackend: highAccuracyBackend,
            contextProvider: { recording in
                SpeechRecognitionRouteContext(
                    mode: .automatic,
                    scenario: .message,
                    frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                    recordingDuration: recording.duration,
                    hasLowConfidenceSignal: false,
                    hasChineseMisclassifiedAsEnglishSignal: false,
                    isLowPowerModeEnabled: false,
                    localModelState: .warm,
                    contextualTerms: terms
                )
            }
        )

        _ = try await backend.transcribe(recording: AudioRecording(fileURL: URL(fileURLWithPath: "/tmp/test.m4a"), duration: 3))

        XCTAssertEqual(fastBackend.requestedContextualTerms, [Array(terms.prefix(100))])
    }

    func testSystemSpeechBackendDefaultsToChineseLocaleOnly() {
        let backend = SFSpeechRecognitionBackend()

        XCTAssertEqual(backend.localeIdentifiers, ["zh-CN"])
    }

    func testSystemSpeechRequestEnablesAutomaticPunctuation() {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let request = SystemSpeechRecognitionRequestFactory.make(
            fileURL: url,
            contextualTerms: ["ReadyType", "GitHub"]
        )

        XCTAssertTrue(request.addsPunctuation)
        XCTAssertTrue(request.shouldReportPartialResults)
        XCTAssertEqual(request.taskHint, .dictation)
        XCTAssertEqual(request.contextualStrings, ["ReadyType", "GitHub"])
    }

    func testFastSystemBackendWrapsSystemSpeechBackend() async throws {
        let systemBackend = MockSpeechRecognitionBackend(result: "system text")
        let backend = FastSystemSpeechBackend(systemSpeechBackend: systemBackend)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribeAudio(at: url)

        XCTAssertEqual(transcript, "system text")
        XCTAssertEqual(systemBackend.requestedURLs, [url])
    }

    func testLocalHighAccuracyBackendDefaultsToWhisperKitEngine() {
        let backend = LocalHighAccuracySpeechBackend()

        XCTAssertEqual(backend.engineKind, .whisperKit)
    }

    func testLocalHighAccuracyBackendUsesInjectedInProcessEngine() async throws {
        let highAccuracyEngine = MockHighAccuracySpeechEngine(transcript: "local high accuracy text")
        let backend = LocalHighAccuracySpeechBackend(engine: highAccuracyEngine)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        let transcript = try await backend.transcribeAudio(at: url)

        XCTAssertEqual(transcript, "local high accuracy text")
        XCTAssertEqual(highAccuracyEngine.requestedURLs, [url])
    }

    func testPrewarmAndHighAccuracyBackendCanShareEngineInstance() async throws {
        let sharedEngine = MockHighAccuracySpeechEngine(transcript: "prewarmed high accuracy text")
        let warmupService = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .alwaysAllow,
            warmup: {
                try await sharedEngine.prewarm()
            }
        )
        let backend = LocalHighAccuracySpeechBackend(engine: sharedEngine)
        let url = URL(fileURLWithPath: "/tmp/test.m4a")

        await warmupService.prewarmIfAllowed(reason: "test")
        let transcript = try await backend.transcribeAudio(at: url)

        XCTAssertEqual(warmupService.state, .warm)
        XCTAssertEqual(transcript, "prewarmed high accuracy text")
        XCTAssertEqual(sharedEngine.prewarmCallCount, 1)
        XCTAssertEqual(sharedEngine.requestedURLs, [url])
    }
}

private final class MockSpeechRecognitionBackend: SpeechRecognitionBackend {
    private let result: String?
    private let error: Error?
    private let delay: Duration?
    private(set) var requestedURLs: [URL] = []

    init(result: String, delay: Duration? = nil) {
        self.result = result
        self.error = nil
        self.delay = delay
    }

    init(error: Error) {
        self.result = nil
        self.error = error
        self.delay = nil
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        requestedURLs.append(fileURL)

        if let delay {
            try await Task.sleep(for: delay)
        }

        if let error {
            throw error
        }

        return result ?? ""
    }
}

private final class MockContextualSpeechRecognitionBackend: ContextualSpeechRecognitionBackend {
    private let result: String
    private let delay: Duration?
    private(set) var requestedURLs: [URL] = []
    private(set) var requestedContextualTerms: [[String]] = []

    init(result: String, delay: Duration? = nil) {
        self.result = result
        self.delay = delay
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        requestedURLs.append(fileURL)
        requestedContextualTerms.append(contextualTerms)

        if let delay {
            try await Task.sleep(for: delay)
        }

        return result
    }
}

private final class MockCandidateSpeechRecognitionBackend: SpeechRecognitionBackend, SpeechRecognitionCandidateBackend {
    private let candidate: SpeechRecognitionCandidate
    private let delay: Duration?
    private(set) var requestedURLs: [URL] = []
    private(set) var requestedContextualTerms: [[String]] = []

    init(candidate: SpeechRecognitionCandidate, delay: Duration? = nil) {
        self.candidate = candidate
        self.delay = delay
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        try await recognizeAudio(at: fileURL, contextualTerms: []).transcript
    }

    func recognizeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> SpeechRecognitionCandidate {
        requestedURLs.append(fileURL)
        requestedContextualTerms.append(contextualTerms)

        if let delay {
            try await Task.sleep(for: delay)
        }

        return candidate
    }
}

private final class MockHighAccuracySpeechEngine: LocalHighAccuracySpeechEngine {
    private let transcript: String?
    private let error: Error?
    private(set) var requestedURLs: [URL] = []
    private(set) var prewarmCallCount = 0

    init(transcript: String) {
        self.transcript = transcript
        self.error = nil
    }

    init(error: Error) {
        self.transcript = nil
        self.error = error
    }

    func transcribeAudio(at fileURL: URL) async throws -> String {
        requestedURLs.append(fileURL)

        if let error {
            throw error
        }

        return transcript ?? ""
    }

    func prewarm() async throws {
        prewarmCallCount += 1
    }
}
