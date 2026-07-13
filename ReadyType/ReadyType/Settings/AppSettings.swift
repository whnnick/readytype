import Foundation

struct AppSettings: Equatable {
    var defaultMode: OutputMode
    var deepSeekBaseURL: URL
    var deepSeekModel: String
    var pasteAutomatically: Bool
    var chineseTextStyle: ChineseTextStyle
    var speechRecognitionMode: SpeechRecognitionMode
    var isHighAccuracyRecognitionEnabled: Bool
    var isIdlePrewarmEnabled: Bool
    var isVocabularyLearningSuggestionsEnabled: Bool
    var isAnonymousAnalyticsEnabled: Bool
    var voiceShortcut: VoiceShortcutConfiguration

    init(
        defaultMode: OutputMode,
        deepSeekBaseURL: URL,
        deepSeekModel: String,
        pasteAutomatically: Bool,
        chineseTextStyle: ChineseTextStyle = .simplified,
        speechRecognitionMode: SpeechRecognitionMode = .automatic,
        isHighAccuracyRecognitionEnabled: Bool = false,
        isIdlePrewarmEnabled: Bool = true,
        isVocabularyLearningSuggestionsEnabled: Bool = true,
        isAnonymousAnalyticsEnabled: Bool = true,
        voiceShortcut: VoiceShortcutConfiguration = .default
    ) {
        self.defaultMode = defaultMode
        self.deepSeekBaseURL = deepSeekBaseURL
        self.deepSeekModel = deepSeekModel
        self.pasteAutomatically = pasteAutomatically
        self.chineseTextStyle = chineseTextStyle
        self.speechRecognitionMode = speechRecognitionMode
        self.isHighAccuracyRecognitionEnabled = isHighAccuracyRecognitionEnabled
        self.isIdlePrewarmEnabled = isIdlePrewarmEnabled
        self.isVocabularyLearningSuggestionsEnabled = isVocabularyLearningSuggestionsEnabled
        self.isAnonymousAnalyticsEnabled = isAnonymousAnalyticsEnabled
        self.voiceShortcut = voiceShortcut
    }

    static let `default` = AppSettings(
        defaultMode: .aiCleanup,
        deepSeekBaseURL: DeepSeekConfiguration.default.baseURL,
        deepSeekModel: DeepSeekConfiguration.default.model,
        pasteAutomatically: true,
        chineseTextStyle: .simplified,
        speechRecognitionMode: .automatic,
        isHighAccuracyRecognitionEnabled: false,
        isIdlePrewarmEnabled: true,
        isVocabularyLearningSuggestionsEnabled: true,
        isAnonymousAnalyticsEnabled: true,
        voiceShortcut: .default
    )
}
