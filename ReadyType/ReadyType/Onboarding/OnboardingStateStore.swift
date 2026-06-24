import Foundation

struct OnboardingState: Equatable {
    var hasCompletedOnboarding: Bool
    var hasSkippedLocalSpeechModel: Bool
    var hasShownPostFirstUseModelPrompt: Bool
    var preferredSpeechRecognitionMode: SpeechRecognitionMode

    var shouldShowOnboarding: Bool {
        !hasCompletedOnboarding
    }

    static let `default` = OnboardingState(
        hasCompletedOnboarding: false,
        hasSkippedLocalSpeechModel: false,
        hasShownPostFirstUseModelPrompt: false,
        preferredSpeechRecognitionMode: .automatic
    )
}

final class OnboardingStateStore {
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let hasSkippedLocalSpeechModel = "hasSkippedLocalSpeechModel"
        static let hasShownPostFirstUseModelPrompt = "hasShownPostFirstUseModelPrompt"
        static let preferredSpeechRecognitionMode = "onboardingPreferredSpeechRecognitionMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> OnboardingState {
        let defaultState = OnboardingState.default

        return OnboardingState(
            hasCompletedOnboarding: boolValue(
                forKey: Keys.hasCompletedOnboarding,
                defaultValue: defaultState.hasCompletedOnboarding
            ),
            hasSkippedLocalSpeechModel: boolValue(
                forKey: Keys.hasSkippedLocalSpeechModel,
                defaultValue: defaultState.hasSkippedLocalSpeechModel
            ),
            hasShownPostFirstUseModelPrompt: boolValue(
                forKey: Keys.hasShownPostFirstUseModelPrompt,
                defaultValue: defaultState.hasShownPostFirstUseModelPrompt
            ),
            preferredSpeechRecognitionMode: defaults.string(forKey: Keys.preferredSpeechRecognitionMode)
                .flatMap(SpeechRecognitionMode.init(rawValue:))
                ?? defaultState.preferredSpeechRecognitionMode
        )
    }

    func save(_ state: OnboardingState) {
        defaults.set(state.hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        defaults.set(state.hasSkippedLocalSpeechModel, forKey: Keys.hasSkippedLocalSpeechModel)
        defaults.set(state.hasShownPostFirstUseModelPrompt, forKey: Keys.hasShownPostFirstUseModelPrompt)
        defaults.set(state.preferredSpeechRecognitionMode.rawValue, forKey: Keys.preferredSpeechRecognitionMode)
    }

    private func boolValue(forKey key: String, defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }

        return defaults.bool(forKey: key)
    }
}
