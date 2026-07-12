import XCTest
@testable import ReadyType

final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ReadyTypeTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSettingsStorePersistsNonSecretSettings() throws {
        let store = SettingsStore(defaults: defaults)
        let settings = AppSettings(
            defaultMode: .promptOutput,
            deepSeekBaseURL: URL(string: "https://proxy.example.com/v1")!,
            deepSeekModel: "deepseek-reasoner",
            pasteAutomatically: false,
            chineseTextStyle: .traditional,
            speechRecognitionMode: .highAccuracyLocal,
            isHighAccuracyRecognitionEnabled: true,
            isIdlePrewarmEnabled: false,
            isVocabularyLearningSuggestionsEnabled: false,
            voiceShortcut: VoiceShortcutConfiguration(trigger: .doubleControl)
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
    }

    func testSettingsStoreFallsBackToDefaultsForMissingValues() {
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.load(), .default)
    }

    func testDefaultSettingsUseDeepSeekV4Flash() {
        XCTAssertEqual(AppSettings.default.deepSeekBaseURL.absoluteString, "https://api.deepseek.com")
        XCTAssertEqual(AppSettings.default.deepSeekModel, "deepseek-v4-flash")
    }

    func testDefaultDeepSeekTimeoutKeepsVoiceInputResponsive() {
        XCTAssertLessThanOrEqual(DeepSeekConfiguration.default.timeoutSeconds, 12)
    }

    func testDefaultSettingsUseAutomaticFastFirstRecognition() {
        XCTAssertEqual(AppSettings.default.speechRecognitionMode, .automatic)
        XCTAssertFalse(AppSettings.default.isHighAccuracyRecognitionEnabled)
        XCTAssertTrue(AppSettings.default.isIdlePrewarmEnabled)
        XCTAssertTrue(AppSettings.default.isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(AppSettings.default.voiceShortcut, .default)
    }

    func testSettingsStoreFallsBackToRecognitionDefaultsForMissingValues() {
        defaults.set(OutputMode.dictation.rawValue, forKey: "defaultMode")
        defaults.set("https://proxy.example.com", forKey: "deepSeekBaseURL")
        defaults.set("custom-model", forKey: "deepSeekModel")
        defaults.set(false, forKey: "pasteAutomatically")
        let store = SettingsStore(defaults: defaults)

        let settings = store.load()

        XCTAssertEqual(settings.defaultMode, .dictation)
        XCTAssertEqual(settings.speechRecognitionMode, .automatic)
        XCTAssertFalse(settings.isHighAccuracyRecognitionEnabled)
        XCTAssertTrue(settings.isIdlePrewarmEnabled)
        XCTAssertTrue(settings.isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(settings.voiceShortcut, .default)
    }

    func testSettingsStoreFallsBackToDefaultShortcutForInvalidStoredValue() {
        defaults.set("tripleEscape", forKey: "voiceShortcutTrigger")
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.load().voiceShortcut, .default)
    }

    func testSettingsStoreMigratesOldDeepSeekChatDefaultToV4Flash() {
        defaults.set("deepseek-chat", forKey: "deepSeekModel")
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.load().deepSeekModel, "deepseek-v4-flash")
    }

    func testSettingsStoreDoesNotPersistAPIKeyField() {
        let store = SettingsStore(defaults: defaults)

        store.save(.default)

        XCTAssertNil(defaults.string(forKey: "deepSeekAPIKey"))
        XCTAssertNil(defaults.string(forKey: "apiKey"))
        XCTAssertNil(defaults.string(forKey: "providerAPIKey"))
    }
}
