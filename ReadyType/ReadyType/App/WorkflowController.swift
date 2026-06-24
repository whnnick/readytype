import Foundation

@MainActor
protocol TranscriptHandling: AnyObject {
    func handleTranscript(_ transcript: String) async throws
}

@MainActor
final class WorkflowController {
    typealias SettingsProvider = () -> AppSettings
    typealias ScenarioProvider = (String) -> OutputScenario
    typealias OutputContextProvider = (String) -> OutputContext
    typealias VocabularySuggestionProvider = (String, ProcessedOutput, OutputContext) -> [UserVocabularySuggestion]

    private let appState: AppState
    private let settingsProvider: SettingsProvider
    private let outputProcessor: OutputProcessing
    private let textDelivery: TextDelivering
    private let outputContextProvider: OutputContextProvider
    private let vocabularySuggestionProvider: VocabularySuggestionProvider
    private let now: () -> Date

    init(
        appState: AppState,
        settingsProvider: @escaping SettingsProvider,
        outputProcessor: OutputProcessing,
        textDelivery: TextDelivering,
        scenarioProvider: @escaping ScenarioProvider = { _ in .generic },
        outputContextProvider: OutputContextProvider? = nil,
        vocabularySuggestionProvider: @escaping VocabularySuggestionProvider = { _, _, _ in [] },
        now: @escaping () -> Date = Date.init
    ) {
        self.appState = appState
        self.settingsProvider = settingsProvider
        self.outputProcessor = outputProcessor
        self.textDelivery = textDelivery
        self.outputContextProvider = outputContextProvider ?? { transcript in
            OutputContext(scenario: scenarioProvider(transcript))
        }
        self.vocabularySuggestionProvider = vocabularySuggestionProvider
        self.now = now
    }

    func handleTranscript(_ transcript: String) async throws {
        let settings = settingsProvider()
        let spokenCommand = SpokenOutputModeCommand.resolve(
            transcript,
            selectedMode: appState.selectedMode
        )
        let mode = spokenCommand.mode
        let transcriptForProcessing = spokenCommand.transcript

        do {
            appState.runtimeState = mode.requiresAI ? .processingAI : .transcribing
            let outputContext = outputContextProvider(transcriptForProcessing)
            let output = try await outputProcessor.process(
                transcriptForProcessing,
                mode: mode,
                context: outputContext
            )
            appState.lastOutput = output.finalText
            appState.userVocabularySuggestions = settings.isVocabularyLearningSuggestionsEnabled
                ? vocabularySuggestionProvider(transcriptForProcessing, output, outputContext)
                : []
            appState.lastProcessingSummary = Self.processingSummary(
                for: output,
                mode: mode,
                scenario: outputContext.scenario,
                advisory: SpeechQualityAdvisor.advisory(
                    for: SpeechQualityAdvisoryRequest(
                        transcript: transcriptForProcessing,
                        recognitionMode: appState.speechRecognitionMode,
                        isHighAccuracyRecognitionEnabled: appState.isHighAccuracyRecognitionEnabled,
                        localSpeechModelState: appState.localSpeechModelState
                    )
                )
            )
            let deliveryResult = try textDelivery.deliver(
                output.finalText,
                pasteAutomatically: settings.pasteAutomatically
            )
            appState.lastVoiceRunMetrics?.outputCompletedAt = now()
            if let summaryLine = appState.lastVoiceRunMetrics?.summaryLine {
                appState.lastProcessingSummary = "\(appState.lastProcessingSummary ?? "")\n\(summaryLine)"
            }

            switch deliveryResult {
            case .pasted:
                appState.runtimeState = .pasted
                appState.lastMessage = output.warning.map { "\($0.userMessage) 已使用本地处理后的文本。" } ?? "已粘贴"
            case .copiedFallback:
                appState.runtimeState = .copiedFallback
                appState.lastMessage = "已复制到剪贴板"
            }
        } catch let error as ReadyTypeError {
            appState.runtimeState = .error(error.userMessage)
            appState.lastMessage = error.userMessage
            throw error
        } catch {
            let readyTypeError = ReadyTypeError.pasteFailed
            appState.runtimeState = .error(readyTypeError.userMessage)
            appState.lastMessage = readyTypeError.userMessage
            throw readyTypeError
        }
    }

    private static func processingSummary(
        for output: ProcessedOutput,
        mode: OutputMode,
        scenario: OutputScenario,
        advisory: SpeechQualityAdvisory?
    ) -> String {
        let summary: String

        guard mode.requiresAI else {
            summary = "\(mode.displayName)：未调用 DeepSeek"
            return append(advisory, to: summary)
        }

        if output.usedFallback {
            let reason = output.warning?.userMessage
            let reasonPrefix = reason.map { "\($0)" } ?? "原因未知。"
            summary = "DeepSeek 调用失败：\(reasonPrefix)已回退为本地处理后的文本"
            return append(advisory, to: summary)
        }

        summary = "已调用 DeepSeek：\(mode.displayName) / \(scenario.displayName)"
        return append(advisory, to: summary)
    }

    private static func append(_ advisory: SpeechQualityAdvisory?, to summary: String) -> String {
        guard let advisory else {
            return summary
        }

        return "\(summary)\n提示：\(advisory.message)"
    }
}

extension WorkflowController: TranscriptHandling {}
