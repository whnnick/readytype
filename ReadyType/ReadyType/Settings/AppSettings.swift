import Foundation

struct AppSettings: Equatable {
    var defaultMode: OutputMode
    var deepSeekBaseURL: URL
    var deepSeekModel: String
    var pasteAutomatically: Bool
    var speechRecognitionMode: SpeechRecognitionMode
    var isHighAccuracyRecognitionEnabled: Bool
    var isIdlePrewarmEnabled: Bool
    var isVocabularyLearningSuggestionsEnabled: Bool
    var voiceShortcut: VoiceShortcutConfiguration

    init(
        defaultMode: OutputMode,
        deepSeekBaseURL: URL,
        deepSeekModel: String,
        pasteAutomatically: Bool,
        speechRecognitionMode: SpeechRecognitionMode = .automatic,
        isHighAccuracyRecognitionEnabled: Bool = false,
        isIdlePrewarmEnabled: Bool = true,
        isVocabularyLearningSuggestionsEnabled: Bool = true,
        voiceShortcut: VoiceShortcutConfiguration = .default
    ) {
        self.defaultMode = defaultMode
        self.deepSeekBaseURL = deepSeekBaseURL
        self.deepSeekModel = deepSeekModel
        self.pasteAutomatically = pasteAutomatically
        self.speechRecognitionMode = speechRecognitionMode
        self.isHighAccuracyRecognitionEnabled = isHighAccuracyRecognitionEnabled
        self.isIdlePrewarmEnabled = isIdlePrewarmEnabled
        self.isVocabularyLearningSuggestionsEnabled = isVocabularyLearningSuggestionsEnabled
        self.voiceShortcut = voiceShortcut
    }

    static let `default` = AppSettings(
        defaultMode: .aiCleanup,
        deepSeekBaseURL: DeepSeekConfiguration.default.baseURL,
        deepSeekModel: DeepSeekConfiguration.default.model,
        pasteAutomatically: true,
        speechRecognitionMode: .automatic,
        isHighAccuracyRecognitionEnabled: false,
        isIdlePrewarmEnabled: true,
        isVocabularyLearningSuggestionsEnabled: true,
        voiceShortcut: .default
    )
}
