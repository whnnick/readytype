import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published private(set) var state: OnboardingState

    private let onboardingStore: OnboardingStateStore
    private let settingsStore: SettingsStore

    init(
        onboardingStore: OnboardingStateStore = OnboardingStateStore(),
        settingsStore: SettingsStore = SettingsStore()
    ) {
        self.onboardingStore = onboardingStore
        self.settingsStore = settingsStore
        self.state = onboardingStore.load()
    }

    var shouldShowOnboarding: Bool {
        state.shouldShowOnboarding
    }

    func skipLocalSpeechModel() {
        persistOnboarding(
            hasCompletedOnboarding: true,
            hasSkippedLocalSpeechModel: true,
            preferredMode: .automatic
        )
        updateRecognitionSettings(
            mode: .automatic,
            isHighAccuracyEnabled: false,
            isIdlePrewarmEnabled: true
        )
    }

    func enableLocalSpeechModel() {
        persistOnboarding(
            hasCompletedOnboarding: true,
            hasSkippedLocalSpeechModel: false,
            preferredMode: .automatic
        )
        updateRecognitionSettings(
            mode: .automatic,
            isHighAccuracyEnabled: true,
            isIdlePrewarmEnabled: true
        )
    }

    func dismissOnboarding() {
        persistOnboarding(
            hasCompletedOnboarding: true,
            hasSkippedLocalSpeechModel: state.hasSkippedLocalSpeechModel,
            preferredMode: state.preferredSpeechRecognitionMode
        )
    }

    func shouldShowPostFirstUseModelPrompt(after runtimeState: RuntimeState) -> Bool {
        guard runtimeState == .pasted else {
            return false
        }

        let latestState = onboardingStore.load()
        let settings = settingsStore.load()
        return latestState.hasCompletedOnboarding
            && latestState.hasSkippedLocalSpeechModel
            && !latestState.hasShownPostFirstUseModelPrompt
            && !settings.isHighAccuracyRecognitionEnabled
    }

    func markPostFirstUseModelPromptShown() {
        var updatedState = onboardingStore.load()
        updatedState.hasShownPostFirstUseModelPrompt = true
        onboardingStore.save(updatedState)
        state = updatedState
    }

    private func persistOnboarding(
        hasCompletedOnboarding: Bool,
        hasSkippedLocalSpeechModel: Bool,
        preferredMode: SpeechRecognitionMode
    ) {
        var updatedState = state
        updatedState.hasCompletedOnboarding = hasCompletedOnboarding
        updatedState.hasSkippedLocalSpeechModel = hasSkippedLocalSpeechModel
        updatedState.preferredSpeechRecognitionMode = preferredMode
        onboardingStore.save(updatedState)
        state = updatedState
    }

    private func updateRecognitionSettings(
        mode: SpeechRecognitionMode,
        isHighAccuracyEnabled: Bool,
        isIdlePrewarmEnabled: Bool
    ) {
        var settings = settingsStore.load()
        settings.speechRecognitionMode = mode
        settings.isHighAccuracyRecognitionEnabled = isHighAccuracyEnabled
        settings.isIdlePrewarmEnabled = isIdlePrewarmEnabled
        settingsStore.save(settings)
    }
}
