import XCTest
@testable import ReadyType

@MainActor
final class WorkflowControllerTests: XCTestCase {
    func testRunsDictationTranscriptThroughProcessorAndPasteService() async throws {
        let appState = AppState(selectedMode: .dictation)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "raw words",
                finalText: "raw words",
                usedAI: false,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { AppSettings(defaultMode: .dictation, deepSeekBaseURL: URL(string: "https://api.deepseek.com")!, deepSeekModel: "deepseek-chat", pasteAutomatically: true) },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript(" raw words ")

        XCTAssertEqual(processor.requests.map(\.transcript), [" raw words "])
        XCTAssertEqual(processor.requests.map(\.mode), [.dictation])
        XCTAssertEqual(processor.requests.map(\.scenario), [.generic])
        XCTAssertEqual(pasteService.requests.map(\.text), ["raw words"])
        XCTAssertEqual(pasteService.requests.map(\.pasteAutomatically), [true])
        XCTAssertEqual(appState.runtimeState, .pasted)
        XCTAssertEqual(appState.lastMessage, "已粘贴")
        XCTAssertEqual(appState.lastProcessingSummary, "直接转文字：未调用 DeepSeek")
    }

    func testSpokenDictationCommandOverridesSelectedAIMode() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "今天晚上先不继续加新功能",
                finalText: "今天晚上先不继续加新功能",
                usedAI: false,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript("直接转文字，今天晚上先不继续加新功能")

        XCTAssertEqual(processor.requests.map(\.transcript), ["今天晚上先不继续加新功能"])
        XCTAssertEqual(processor.requests.map(\.mode), [.dictation])
        XCTAssertEqual(pasteService.requests.map(\.text), ["今天晚上先不继续加新功能"])
        XCTAssertEqual(appState.lastProcessingSummary, "直接转文字：未调用 DeepSeek")
    }

    func testSpokenTranslationCommandOverridesSelectedCleanupMode() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "ReadyType 会保护产品名",
                finalText: "ReadyType protects product names.",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript("翻译成英文，ReadyType 会保护产品名")

        XCTAssertEqual(processor.requests.map(\.transcript), ["ReadyType 会保护产品名"])
        XCTAssertEqual(processor.requests.map(\.mode), [.translationToEnglish])
        XCTAssertEqual(pasteService.requests.map(\.text), ["ReadyType protects product names."])
        XCTAssertEqual(appState.lastProcessingSummary, "已调用 DeepSeek：翻译成英文 / 通用")
    }

    func testRecognitionQualityAdvisoryIsAppendedToProcessingSummary() async throws {
        let appState = AppState(
            selectedMode: .dictation,
            speechRecognitionMode: .automatic,
            isHighAccuracyRecognitionEnabled: false,
            localSpeechModelState: .notInstalled
        )
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "I want to send an email to John about the project delay",
                finalText: "I want to send an email to John about the project delay",
                usedAI: false,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript("I want to send an email to John about the project delay")

        XCTAssertEqual(appState.runtimeState, .pasted)
        XCTAssertEqual(appState.lastMessage, "已粘贴")
        XCTAssertEqual(
            appState.lastProcessingSummary,
            "直接转文字：未调用 DeepSeek\n提示：识别结果偏英文；如果你刚才说的是中文，可在设置中启用更准确的本机识别。"
        )
    }

    func testCopiedFallbackUpdatesStateAndMessage() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "rough words",
                finalText: "clean words",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .copiedFallback)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { AppSettings(defaultMode: .aiCleanup, deepSeekBaseURL: URL(string: "https://api.deepseek.com")!, deepSeekModel: "deepseek-chat", pasteAutomatically: true) },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript("rough words")

        XCTAssertEqual(appState.runtimeState, .copiedFallback)
        XCTAssertEqual(appState.lastMessage, "已复制到剪贴板")
        XCTAssertEqual(appState.lastProcessingSummary, "已调用 DeepSeek：整理成文 / 通用")
    }

    func testTimingSummaryIsAppendedAfterOutputCompletes() async throws {
        let appState = AppState(
            selectedMode: .dictation,
            lastVoiceRunMetrics: VoiceRunMetrics(
                recordingStartedAt: Date(timeIntervalSince1970: 10),
                recordingStoppedAt: Date(timeIntervalSince1970: 13),
                transcriptReadyAt: Date(timeIntervalSince1970: 14),
                recordingDuration: 3
            )
        )
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "raw words",
                finalText: "raw words",
                usedAI: false,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService,
            now: { Date(timeIntervalSince1970: 15.5) }
        )

        try await controller.handleTranscript("raw words")

        XCTAssertEqual(appState.lastVoiceRunMetrics?.stopToOutputLatencyMilliseconds, 2_500)
        XCTAssertEqual(appState.lastVoiceRunMetrics?.totalCompletionLatencyMilliseconds, 5_500)
        XCTAssertEqual(
            appState.lastProcessingSummary,
            "直接转文字：未调用 DeepSeek\n耗时：识别 1000ms / 停止到输出 2500ms / 总计 5500ms"
        )
    }

    func testCurrentRunVocabularySuggestionsAreShownButNotSavedAutomatically() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "请整理 ReadyTap 文档",
                finalText: "请整理 ReadyType 文档",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService,
            vocabularySuggestionProvider: { transcript, output, context in
                XCTAssertEqual(transcript, "请整理 ReadyTap 文档")
                XCTAssertEqual(output.finalText, "请整理 ReadyType 文档")
                XCTAssertEqual(context.scenario, .generic)
                return [
                    UserVocabularySuggestion(
                        value: "ReadyType",
                        kind: .technical,
                        aliases: ["ReadyTap"],
                        reason: "刚才可能想保留这个词"
                    )
                ]
            }
        )

        try await controller.handleTranscript("请整理 ReadyTap 文档")

        XCTAssertEqual(
            appState.userVocabularySuggestions,
            [
                UserVocabularySuggestion(
                    value: "ReadyType",
                    kind: .technical,
                    aliases: ["ReadyTap"],
                    reason: "刚才可能想保留这个词"
                )
            ]
        )
    }

    func testLearningSuggestionsCanBeDisabledWithoutChangingOutput() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "请整理 ReadyTap 文档",
                finalText: "请整理 ReadyType 文档",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        var suggestionProviderWasCalled = false
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: {
                AppSettings(
                    defaultMode: .aiCleanup,
                    deepSeekBaseURL: DeepSeekConfiguration.default.baseURL,
                    deepSeekModel: DeepSeekConfiguration.default.model,
                    pasteAutomatically: true,
                    isVocabularyLearningSuggestionsEnabled: false
                )
            },
            outputProcessor: processor,
            textDelivery: pasteService,
            vocabularySuggestionProvider: { _, _, _ in
                suggestionProviderWasCalled = true
                return [
                    UserVocabularySuggestion(
                        value: "ReadyType",
                        kind: .technical,
                        aliases: ["ReadyTap"],
                        reason: "以后按这个写法处理"
                    )
                ]
            }
        )

        try await controller.handleTranscript("请整理 ReadyTap 文档")

        XCTAssertEqual(appState.lastOutput, "请整理 ReadyType 文档")
        XCTAssertTrue(appState.userVocabularySuggestions.isEmpty)
        XCTAssertFalse(suggestionProviderWasCalled)
    }

    func testScenarioProviderIsPassedToOutputProcessor() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "email words",
                finalText: "email output",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService,
            scenarioProvider: { transcript in
                transcript.contains("email") ? .email : .generic
            }
        )

        try await controller.handleTranscript("email words")

        XCTAssertEqual(processor.requests.map(\.scenario), [.email])
        XCTAssertEqual(appState.lastProcessingSummary, "已调用 DeepSeek：整理成文 / 邮件")
    }

    func testOutputContextProviderIsPassedToOutputProcessor() async throws {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "wechat words",
                finalText: "wechat output",
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService,
            outputContextProvider: { _ in OutputContext(scenario: .message, chatTone: .personal) }
        )

        try await controller.handleTranscript("wechat words")

        XCTAssertEqual(processor.requests.map(\.context), [OutputContext(scenario: .message, chatTone: .personal)])
        XCTAssertEqual(appState.lastProcessingSummary, "已调用 DeepSeek：整理成文 / 聊天")
    }


    func testProcessorWarningIsShownAfterSuccessfulFallbackPaste() async throws {
        let appState = AppState(selectedMode: .promptOutput)
        let processor = MockOutputProcessing(
            result: ProcessedOutput(
                rawTranscript: "rough prompt",
                finalText: "rough prompt",
                usedAI: true,
                usedFallback: true,
                warning: .deepSeekTimeout
            )
        )
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        try await controller.handleTranscript("rough prompt")

        XCTAssertEqual(appState.runtimeState, .pasted)
        XCTAssertEqual(appState.lastMessage, "DeepSeek 请求超时。 已使用本地处理后的文本。")
        XCTAssertEqual(appState.lastProcessingSummary, "DeepSeek 调用失败：DeepSeek 请求超时。已回退为本地处理后的文本")
    }

    func testProcessorErrorUpdatesErrorStateAndDoesNotPaste() async {
        let appState = AppState(selectedMode: .aiCleanup)
        let processor = MockOutputProcessing(error: ReadyTypeError.transcriptionEmpty)
        let pasteService = MockTextDelivering(result: .pasted)
        let controller = WorkflowController(
            appState: appState,
            settingsProvider: { .default },
            outputProcessor: processor,
            textDelivery: pasteService
        )

        do {
            try await controller.handleTranscript("   ")
            XCTFail("Expected transcriptionEmpty")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .transcriptionEmpty)
            XCTAssertEqual(appState.runtimeState, .error("没有识别到语音文字。"))
            XCTAssertEqual(appState.lastMessage, "没有识别到语音文字。")
            XCTAssertTrue(pasteService.requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockOutputProcessing: OutputProcessing {
    struct Request {
        let transcript: String
        let mode: OutputMode
        let scenario: OutputScenario
        let context: OutputContext
    }

    private let result: ProcessedOutput?
    private let error: Error?
    private(set) var requests: [Request] = []

    init(result: ProcessedOutput) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    func process(_ transcript: String, mode: OutputMode) async throws -> ProcessedOutput {
        try await process(transcript, mode: mode, scenario: .generic)
    }

    func process(_ transcript: String, mode: OutputMode, scenario: OutputScenario) async throws -> ProcessedOutput {
        try await process(transcript, mode: mode, context: OutputContext(scenario: scenario))
    }

    func process(_ transcript: String, mode: OutputMode, context: OutputContext) async throws -> ProcessedOutput {
        requests.append(Request(transcript: transcript, mode: mode, scenario: context.scenario, context: context))

        if let error {
            throw error
        }

        return result!
    }
}

private final class MockTextDelivering: TextDelivering {
    struct Request {
        let text: String
        let pasteAutomatically: Bool
    }

    private let result: PasteDeliveryResult
    private(set) var requests: [Request] = []

    init(result: PasteDeliveryResult) {
        self.result = result
    }

    func deliver(_ text: String, pasteAutomatically: Bool) throws -> PasteDeliveryResult {
        requests.append(Request(text: text, pasteAutomatically: pasteAutomatically))
        return result
    }
}
