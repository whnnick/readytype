import Foundation

final class SettingsStore {
    private enum Keys {
        static let defaultMode = "defaultMode"
        static let deepSeekBaseURL = "deepSeekBaseURL"
        static let deepSeekModel = "deepSeekModel"
        static let pasteAutomatically = "pasteAutomatically"
        static let speechRecognitionMode = "speechRecognitionMode"
        static let isHighAccuracyRecognitionEnabled = "isHighAccuracyRecognitionEnabled"
        static let isIdlePrewarmEnabled = "isIdlePrewarmEnabled"
        static let isVocabularyLearningSuggestionsEnabled = "isVocabularyLearningSuggestionsEnabled"
        static let voiceShortcutTrigger = "voiceShortcutTrigger"
        static let voiceShortcutDoublePressInterval = "voiceShortcutDoublePressInterval"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        let defaultSettings = AppSettings.default

        let mode = defaults.string(forKey: Keys.defaultMode)
            .flatMap(OutputMode.init(rawValue:))
            ?? defaultSettings.defaultMode

        let baseURL = defaults.string(forKey: Keys.deepSeekBaseURL)
            .flatMap(URL.init(string:))
            ?? defaultSettings.deepSeekBaseURL

        let model = migratedModel(nonEmptyString(forKey: Keys.deepSeekModel) ?? defaultSettings.deepSeekModel)

        let pasteAutomatically: Bool
        if defaults.object(forKey: Keys.pasteAutomatically) == nil {
            pasteAutomatically = defaultSettings.pasteAutomatically
        } else {
            pasteAutomatically = defaults.bool(forKey: Keys.pasteAutomatically)
        }

        let speechRecognitionMode = defaults.string(forKey: Keys.speechRecognitionMode)
            .flatMap(SpeechRecognitionMode.init(rawValue:))
            ?? defaultSettings.speechRecognitionMode

        let isHighAccuracyRecognitionEnabled = boolValue(
            forKey: Keys.isHighAccuracyRecognitionEnabled,
            defaultValue: defaultSettings.isHighAccuracyRecognitionEnabled
        )

        let isIdlePrewarmEnabled = boolValue(
            forKey: Keys.isIdlePrewarmEnabled,
            defaultValue: defaultSettings.isIdlePrewarmEnabled
        )

        let isVocabularyLearningSuggestionsEnabled = boolValue(
            forKey: Keys.isVocabularyLearningSuggestionsEnabled,
            defaultValue: defaultSettings.isVocabularyLearningSuggestionsEnabled
        )

        let voiceShortcut = loadVoiceShortcut(defaultValue: defaultSettings.voiceShortcut)

        return AppSettings(
            defaultMode: mode,
            deepSeekBaseURL: baseURL,
            deepSeekModel: model,
            pasteAutomatically: pasteAutomatically,
            speechRecognitionMode: speechRecognitionMode,
            isHighAccuracyRecognitionEnabled: isHighAccuracyRecognitionEnabled,
            isIdlePrewarmEnabled: isIdlePrewarmEnabled,
            isVocabularyLearningSuggestionsEnabled: isVocabularyLearningSuggestionsEnabled,
            voiceShortcut: voiceShortcut
        )
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.defaultMode.rawValue, forKey: Keys.defaultMode)
        defaults.set(settings.deepSeekBaseURL.absoluteString, forKey: Keys.deepSeekBaseURL)
        defaults.set(settings.deepSeekModel, forKey: Keys.deepSeekModel)
        defaults.set(settings.pasteAutomatically, forKey: Keys.pasteAutomatically)
        defaults.set(settings.speechRecognitionMode.rawValue, forKey: Keys.speechRecognitionMode)
        defaults.set(settings.isHighAccuracyRecognitionEnabled, forKey: Keys.isHighAccuracyRecognitionEnabled)
        defaults.set(settings.isIdlePrewarmEnabled, forKey: Keys.isIdlePrewarmEnabled)
        defaults.set(settings.isVocabularyLearningSuggestionsEnabled, forKey: Keys.isVocabularyLearningSuggestionsEnabled)
        defaults.set(settings.voiceShortcut.trigger.rawValue, forKey: Keys.voiceShortcutTrigger)
        defaults.set(settings.voiceShortcut.doublePressInterval, forKey: Keys.voiceShortcutDoublePressInterval)
    }

    private func nonEmptyString(forKey key: String) -> String? {
        guard let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }

        return value
    }

    private func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }

    private func migratedModel(_ model: String) -> String {
        if model == "deepseek-chat" {
            return AppSettings.default.deepSeekModel
        }

        return model
    }

    private func loadVoiceShortcut(defaultValue: VoiceShortcutConfiguration) -> VoiceShortcutConfiguration {
        let trigger = defaults.string(forKey: Keys.voiceShortcutTrigger)
            .flatMap(VoiceShortcutTrigger.init(rawValue:))
            ?? defaultValue.trigger

        let interval: TimeInterval
        if defaults.object(forKey: Keys.voiceShortcutDoublePressInterval) == nil {
            interval = defaultValue.doublePressInterval
        } else {
            interval = defaults.double(forKey: Keys.voiceShortcutDoublePressInterval)
        }

        guard interval > 0 else {
            return defaultValue
        }

        return VoiceShortcutConfiguration(trigger: trigger, doublePressInterval: interval)
    }
}
