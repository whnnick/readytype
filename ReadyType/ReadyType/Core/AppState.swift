import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedMode: OutputMode
    @Published var scenarioSelection: OutputScenarioSelection
    @Published var runtimeState: RuntimeState
    @Published var lastMessage: String?
    @Published var lastTranscript: String?
    @Published var lastOutput: String?
    @Published var lastProcessingSummary: String?
    @Published var speechRecognitionMode: SpeechRecognitionMode
    @Published var isHighAccuracyRecognitionEnabled: Bool
    @Published var localSpeechModelState: LocalSpeechModelState
    @Published var voiceShortcut: VoiceShortcutConfiguration
    @Published var lastSpeechRecognitionRouteDecision: SpeechRecognitionRouteDecision?
    @Published var lastVoiceRunMetrics: VoiceRunMetrics?
    @Published var userVocabularySuggestions: [UserVocabularySuggestion]

    init(
        selectedMode: OutputMode = .aiCleanup,
        scenarioSelection: OutputScenarioSelection = .automatic,
        runtimeState: RuntimeState = .idle,
        lastMessage: String? = nil,
        lastTranscript: String? = nil,
        lastOutput: String? = nil,
        lastProcessingSummary: String? = nil,
        speechRecognitionMode: SpeechRecognitionMode = .automatic,
        isHighAccuracyRecognitionEnabled: Bool = false,
        localSpeechModelState: LocalSpeechModelState = .notInstalled,
        voiceShortcut: VoiceShortcutConfiguration = .default,
        lastSpeechRecognitionRouteDecision: SpeechRecognitionRouteDecision? = nil,
        lastVoiceRunMetrics: VoiceRunMetrics? = nil,
        userVocabularySuggestions: [UserVocabularySuggestion] = []
    ) {
        self.selectedMode = selectedMode
        self.scenarioSelection = scenarioSelection
        self.runtimeState = runtimeState
        self.lastMessage = lastMessage
        self.lastTranscript = lastTranscript
        self.lastOutput = lastOutput
        self.lastProcessingSummary = lastProcessingSummary
        self.speechRecognitionMode = speechRecognitionMode
        self.isHighAccuracyRecognitionEnabled = isHighAccuracyRecognitionEnabled
        self.localSpeechModelState = localSpeechModelState
        self.voiceShortcut = voiceShortcut
        self.lastSpeechRecognitionRouteDecision = lastSpeechRecognitionRouteDecision
        self.lastVoiceRunMetrics = lastVoiceRunMetrics
        self.userVocabularySuggestions = userVocabularySuggestions
    }
}

enum RuntimeState: Equatable {
    case idle
    case recording
    case transcribing
    case processingAI
    case pasted
    case copiedFallback
    case error(String)
}
