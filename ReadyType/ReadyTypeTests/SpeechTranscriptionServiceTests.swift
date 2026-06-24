import XCTest
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

    func testRoutedBackendUsesHighAccuracyOnlyWhenRouterSelectsIt() async throws {
        let fastBackend = MockSpeechRecognitionBackend(result: "fast text")
        let highAccuracyBackend = MockSpeechRecognitionBackend(result: "high accuracy text")
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
        XCTAssertTrue(fastBackend.requestedURLs.isEmpty)
        XCTAssertEqual(routeDecisions, [SpeechRecognitionRouteDecision(backend: .highAccuracyLocal, fallbackReason: nil)])
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
    private(set) var requestedContextualTerms: [[String]] = []

    init(result: String) {
        self.result = result
    }

    func transcribeAudio(at fileURL: URL, contextualTerms: [String]) async throws -> String {
        requestedContextualTerms.append(contextualTerms)
        return result
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
