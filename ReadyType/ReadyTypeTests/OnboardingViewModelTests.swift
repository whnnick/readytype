import XCTest
@testable import ReadyType

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testSkipLocalSpeechModelCompletesOnboardingAndKeepsFastFirstSettings() {
        let context = makeContext()
        defer { context.cleanup() }

        let viewModel = OnboardingViewModel(
            onboardingStore: context.onboardingStore,
            settingsStore: context.settingsStore
        )

        viewModel.skipLocalSpeechModel()

        let onboardingState = context.onboardingStore.load()
        let settings = context.settingsStore.load()
        XCTAssertTrue(onboardingState.hasCompletedOnboarding)
        XCTAssertTrue(onboardingState.hasSkippedLocalSpeechModel)
        XCTAssertEqual(onboardingState.preferredSpeechRecognitionMode, .automatic)
        XCTAssertEqual(settings.speechRecognitionMode, .automatic)
        XCTAssertFalse(settings.isHighAccuracyRecognitionEnabled)
        XCTAssertTrue(settings.isIdlePrewarmEnabled)
        XCTAssertFalse(viewModel.shouldShowOnboarding)
    }

    func testEnableLocalSpeechModelCompletesOnboardingAndEnablesHighAccuracyWithoutStartingDownload() {
        let context = makeContext()
        defer { context.cleanup() }

        let viewModel = OnboardingViewModel(
            onboardingStore: context.onboardingStore,
            settingsStore: context.settingsStore
        )

        viewModel.enableLocalSpeechModel()

        let onboardingState = context.onboardingStore.load()
        let settings = context.settingsStore.load()
        XCTAssertTrue(onboardingState.hasCompletedOnboarding)
        XCTAssertFalse(onboardingState.hasSkippedLocalSpeechModel)
        XCTAssertEqual(onboardingState.preferredSpeechRecognitionMode, .automatic)
        XCTAssertEqual(settings.speechRecognitionMode, .automatic)
        XCTAssertTrue(settings.isHighAccuracyRecognitionEnabled)
        XCTAssertTrue(settings.isIdlePrewarmEnabled)
        XCTAssertFalse(viewModel.shouldShowOnboarding)
    }

    func testDismissOnboardingCompletesWithoutChangingRecognitionSettings() {
        let context = makeContext()
        defer { context.cleanup() }
        context.settingsStore.save(
            AppSettings(
                defaultMode: .dictation,
                deepSeekBaseURL: URL(string: "https://api.deepseek.com")!,
                deepSeekModel: "deepseek-v4-flash",
                pasteAutomatically: false,
                speechRecognitionMode: .fastSystem,
                isHighAccuracyRecognitionEnabled: false,
                isIdlePrewarmEnabled: false
            )
        )
        let viewModel = OnboardingViewModel(
            onboardingStore: context.onboardingStore,
            settingsStore: context.settingsStore
        )

        viewModel.dismissOnboarding()

        XCTAssertTrue(context.onboardingStore.load().hasCompletedOnboarding)
        XCTAssertEqual(context.settingsStore.load().speechRecognitionMode, .fastSystem)
        XCTAssertFalse(context.settingsStore.load().isIdlePrewarmEnabled)
    }

    func testPostFirstUsePromptShowsOnlyOnceAfterUserSkippedLocalSpeechModel() {
        let context = makeContext()
        defer { context.cleanup() }
        context.onboardingStore.save(
            OnboardingState(
                hasCompletedOnboarding: true,
                hasSkippedLocalSpeechModel: true,
                hasShownPostFirstUseModelPrompt: false,
                preferredSpeechRecognitionMode: .automatic
            )
        )
        let viewModel = OnboardingViewModel(
            onboardingStore: context.onboardingStore,
            settingsStore: context.settingsStore
        )

        XCTAssertTrue(viewModel.shouldShowPostFirstUseModelPrompt(after: .pasted))

        viewModel.markPostFirstUseModelPromptShown()

        XCTAssertFalse(viewModel.shouldShowPostFirstUseModelPrompt(after: .pasted))
        XCTAssertTrue(context.onboardingStore.load().hasShownPostFirstUseModelPrompt)
    }

    func testPostFirstUsePromptDoesNotShowForCopyFallbackOrWhenHighAccuracyIsEnabled() {
        let context = makeContext()
        defer { context.cleanup() }
        context.onboardingStore.save(
            OnboardingState(
                hasCompletedOnboarding: true,
                hasSkippedLocalSpeechModel: true,
                hasShownPostFirstUseModelPrompt: false,
                preferredSpeechRecognitionMode: .automatic
            )
        )
        context.settingsStore.save(
            AppSettings(
                defaultMode: .dictation,
                deepSeekBaseURL: URL(string: "https://api.deepseek.com")!,
                deepSeekModel: "deepseek-v4-flash",
                pasteAutomatically: true,
                speechRecognitionMode: .automatic,
                isHighAccuracyRecognitionEnabled: true,
                isIdlePrewarmEnabled: true
            )
        )
        let viewModel = OnboardingViewModel(
            onboardingStore: context.onboardingStore,
            settingsStore: context.settingsStore
        )

        XCTAssertFalse(viewModel.shouldShowPostFirstUseModelPrompt(after: .pasted))
        XCTAssertFalse(viewModel.shouldShowPostFirstUseModelPrompt(after: .copiedFallback))
    }

    private func makeContext() -> TestContext {
        let suiteName = "ReadyTypeOnboardingViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TestContext(
            suiteName: suiteName,
            defaults: defaults,
            onboardingStore: OnboardingStateStore(defaults: defaults),
            settingsStore: SettingsStore(defaults: defaults)
        )
    }
}

private struct TestContext {
    let suiteName: String
    let defaults: UserDefaults
    let onboardingStore: OnboardingStateStore
    let settingsStore: SettingsStore

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}
