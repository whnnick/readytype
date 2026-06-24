import XCTest
@testable import ReadyType

final class OnboardingStateStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReadyTypeOnboardingStateStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultStateShowsOnboardingWithoutBlockingFirstUse() {
        let store = OnboardingStateStore(defaults: defaults)

        let state = store.load()

        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(state.hasSkippedLocalSpeechModel)
        XCTAssertFalse(state.hasShownPostFirstUseModelPrompt)
        XCTAssertEqual(state.preferredSpeechRecognitionMode, .automatic)
        XCTAssertTrue(state.shouldShowOnboarding)
    }

    func testStorePersistsOnboardingState() {
        let store = OnboardingStateStore(defaults: defaults)
        let state = OnboardingState(
            hasCompletedOnboarding: true,
            hasSkippedLocalSpeechModel: true,
            hasShownPostFirstUseModelPrompt: true,
            preferredSpeechRecognitionMode: .fastSystem
        )

        store.save(state)

        XCTAssertEqual(store.load(), state)
    }

    func testInvalidPersistedRecognitionModeFallsBackToAutomatic() {
        defaults.set("unknown-mode", forKey: "onboardingPreferredSpeechRecognitionMode")
        let store = OnboardingStateStore(defaults: defaults)

        XCTAssertEqual(store.load().preferredSpeechRecognitionMode, .automatic)
    }
}
