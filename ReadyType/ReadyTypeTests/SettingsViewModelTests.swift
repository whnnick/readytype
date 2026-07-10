import XCTest
@testable import ReadyType

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadReflectsPersistedSettingsAndKeyPresence() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let store = SettingsStore(defaults: context.defaults)
        store.save(
            AppSettings(
                defaultMode: .promptOutput,
                deepSeekBaseURL: URL(string: "https://proxy.example.com")!,
                deepSeekModel: "deepseek-reasoner",
                pasteAutomatically: false,
                speechRecognitionMode: .highAccuracyLocal,
                isHighAccuracyRecognitionEnabled: true,
                isIdlePrewarmEnabled: false,
                isVocabularyLearningSuggestionsEnabled: false,
                voiceShortcut: VoiceShortcutConfiguration(trigger: .doubleControl)
            )
        )
        try context.keychain.saveAPIKey("secret")

        let viewModel = SettingsViewModel(settingsStore: store, keychainService: context.keychain)

        XCTAssertEqual(viewModel.defaultMode, .promptOutput)
        XCTAssertEqual(viewModel.baseURLText, "https://proxy.example.com")
        XCTAssertEqual(viewModel.model, "deepseek-reasoner")
        XCTAssertFalse(viewModel.pasteAutomatically)
        XCTAssertEqual(viewModel.speechRecognitionMode, .highAccuracyLocal)
        XCTAssertTrue(viewModel.isHighAccuracyRecognitionEnabled)
        XCTAssertFalse(viewModel.isIdlePrewarmEnabled)
        XCTAssertFalse(viewModel.isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(viewModel.voiceShortcut, VoiceShortcutConfiguration(trigger: .doubleControl))
        XCTAssertTrue(viewModel.hasSavedAPIKey)
        XCTAssertEqual(viewModel.apiKeyText, "")
    }

    func testSavePersistsSettingsAndNewAPIKey() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let store = SettingsStore(defaults: context.defaults)
        let viewModel = SettingsViewModel(settingsStore: store, keychainService: context.keychain)
        viewModel.defaultMode = .dictation
        viewModel.baseURLText = "https://api.deepseek.com"
        viewModel.model = "custom-compatible-model"
        viewModel.pasteAutomatically = false
        viewModel.speechRecognitionMode = .fastSystem
        viewModel.isHighAccuracyRecognitionEnabled = true
        viewModel.isIdlePrewarmEnabled = false
        viewModel.isVocabularyLearningSuggestionsEnabled = false
        viewModel.voiceShortcut = VoiceShortcutConfiguration(trigger: .doubleCommand)
        viewModel.apiKeyText = "new-secret"

        try viewModel.save()

        XCTAssertEqual(store.load().defaultMode, .dictation)
        XCTAssertEqual(store.load().deepSeekBaseURL.absoluteString, "https://api.deepseek.com")
        XCTAssertEqual(store.load().deepSeekModel, "custom-compatible-model")
        XCTAssertFalse(store.load().pasteAutomatically)
        XCTAssertEqual(store.load().speechRecognitionMode, .fastSystem)
        XCTAssertTrue(store.load().isHighAccuracyRecognitionEnabled)
        XCTAssertFalse(store.load().isIdlePrewarmEnabled)
        XCTAssertFalse(store.load().isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(store.load().voiceShortcut, VoiceShortcutConfiguration(trigger: .doubleCommand))
        XCTAssertEqual(try context.keychain.loadAPIKey(), "new-secret")
        XCTAssertEqual(viewModel.apiKeyText, "")
        XCTAssertTrue(viewModel.hasSavedAPIKey)
        XCTAssertEqual(viewModel.statusMessage, "设置已保存")
    }

    func testVocabularyLearningSuggestionTogglePersistsImmediately() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let store = SettingsStore(defaults: context.defaults)
        store.save(.default)
        let viewModel = SettingsViewModel(settingsStore: store, keychainService: context.keychain)

        viewModel.setVocabularyLearningSuggestionsEnabled(false)

        XCTAssertFalse(viewModel.isVocabularyLearningSuggestionsEnabled)
        XCTAssertFalse(store.load().isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(viewModel.statusMessage, "已关闭常用词建议")

        viewModel.setVocabularyLearningSuggestionsEnabled(true)

        XCTAssertTrue(viewModel.isVocabularyLearningSuggestionsEnabled)
        XCTAssertTrue(store.load().isVocabularyLearningSuggestionsEnabled)
        XCTAssertEqual(viewModel.statusMessage, "已开启常用词建议")
    }

    func testSaveNotifiesWhenVoiceShortcutChanges() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let store = SettingsStore(defaults: context.defaults)
        var changedShortcut: VoiceShortcutConfiguration?
        let viewModel = SettingsViewModel(
            settingsStore: store,
            keychainService: context.keychain,
            onVoiceShortcutChange: { changedShortcut = $0 }
        )
        viewModel.voiceShortcut = VoiceShortcutConfiguration(trigger: .doubleControl)

        try viewModel.save()

        XCTAssertEqual(changedShortcut, VoiceShortcutConfiguration(trigger: .doubleControl))
    }

    func testSaveRejectsInvalidBaseURL() {
        let context = makeContext()
        defer { context.cleanup() }

        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain
        )
        viewModel.baseURLText = "not a valid url"

        XCTAssertThrowsError(try viewModel.save()) { error in
            XCTAssertEqual(error as? ReadyTypeError, .invalidSettings("服务地址必须是有效的 http(s) 地址。"))
        }
    }

    func testClearAPIKeyDeletesSavedKey() throws {
        let context = makeContext()
        defer { context.cleanup() }

        try context.keychain.saveAPIKey("secret")
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain
        )

        try viewModel.clearAPIKey()

        XCTAssertNil(try context.keychain.loadAPIKey())
        XCTAssertFalse(viewModel.hasSavedAPIKey)
        XCTAssertEqual(viewModel.statusMessage, "DeepSeek 密钥已清除")
    }

    func testAPIConnectionTestUsesSavedKeyWhenInputIsEmpty() async throws {
        let context = makeContext()
        defer { context.cleanup() }

        try context.keychain.saveAPIKey("saved-secret")
        var usedAPIKey: String?
        let tester = APIConnectionTester { _, apiKey in
            usedAPIKey = apiKey
            return MockSettingsConnectionProvider(result: .success("OK"))
        }
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            apiConnectionTester: tester
        )
        viewModel.apiKeyText = ""

        await viewModel.testAPIConnection()

        XCTAssertEqual(usedAPIKey, "saved-secret")
        XCTAssertEqual(viewModel.apiConnectionTestState.status, .success)
    }

    func testAPIConnectionTestMapsInvalidBaseURLToNetworkFailure() async {
        let context = makeContext()
        defer { context.cleanup() }

        let tester = APIConnectionTester { _, _ in
            XCTFail("Invalid Base URL should not create a provider")
            return MockSettingsConnectionProvider(result: .success("OK"))
        }
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            apiConnectionTester: tester
        )
        viewModel.baseURLText = "not a url"
        viewModel.apiKeyText = "test-key"

        await viewModel.testAPIConnection()

        XCTAssertEqual(viewModel.apiConnectionTestState.status, .networkFailed)
    }

    func testLoadReflectsLocalSpeechModelStateWhenHighAccuracyIsEnabled() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        try context.writeSpeechModelDirectory()
        let store = SettingsStore(defaults: context.defaults)
        store.save(
            AppSettings(
                defaultMode: .dictation,
                deepSeekBaseURL: URL(string: "https://api.deepseek.com")!,
                deepSeekModel: "deepseek-chat",
                pasteAutomatically: true,
                speechRecognitionMode: .automatic,
                isHighAccuracyRecognitionEnabled: true,
                isIdlePrewarmEnabled: true
            )
        )

        let viewModel = SettingsViewModel(
            settingsStore: store,
            keychainService: context.keychain,
            localSpeechModelManager: manager
        )

        XCTAssertEqual(viewModel.localSpeechModelState, .downloadedCold)
    }

    func testDownloadHighAccuracySpeechModelUpdatesStateAndStatusMessage() async throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        let installer = MockSettingsModelInstaller(progressValues: [0.4, 1.0])
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager,
            localSpeechModelInstaller: installer
        )

        await viewModel.downloadHighAccuracySpeechModel()

        XCTAssertEqual(viewModel.localSpeechModelState, .downloadedCold)
        XCTAssertFalse(viewModel.isDownloadingSpeechModel)
        XCTAssertEqual(viewModel.statusMessage, "高精度语音包已安装，尚未准备好")
        XCTAssertEqual(installer.installCallCount, 1)
    }

    func testDownloadHighAccuracySpeechModelImmediatelyPrewarmsWhenAllowed() async throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        let installer = MockSettingsModelInstaller(progressValues: [1.0])
        var prewarmCallCount = 0
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager,
            localSpeechModelInstaller: installer,
            postDownloadPrewarm: {
                prewarmCallCount += 1
                return .warm
            }
        )
        viewModel.isHighAccuracyRecognitionEnabled = true
        viewModel.isIdlePrewarmEnabled = true

        await viewModel.downloadHighAccuracySpeechModel()

        XCTAssertEqual(prewarmCallCount, 1)
        XCTAssertEqual(viewModel.localSpeechModelState, .warm)
        XCTAssertFalse(viewModel.isDownloadingSpeechModel)
        XCTAssertEqual(viewModel.statusMessage, "高精度识别已准备好")
    }

    func testDownloadHighAccuracySpeechModelDoesNotPrewarmWhenIdlePrewarmIsOff() async throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        let installer = MockSettingsModelInstaller(progressValues: [1.0])
        var prewarmCallCount = 0
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager,
            localSpeechModelInstaller: installer,
            postDownloadPrewarm: {
                prewarmCallCount += 1
                return .warm
            }
        )
        viewModel.isHighAccuracyRecognitionEnabled = true
        viewModel.isIdlePrewarmEnabled = false

        await viewModel.downloadHighAccuracySpeechModel()

        XCTAssertEqual(prewarmCallCount, 0)
        XCTAssertEqual(viewModel.localSpeechModelState, .downloadedCold)
        XCTAssertEqual(viewModel.statusMessage, "高精度语音包已安装，尚未准备好")
    }

    func testDeleteHighAccuracySpeechModelRemovesInstalledModelAndUpdatesState() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        try context.writeSpeechModelDirectory()
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager
        )

        try viewModel.deleteHighAccuracySpeechModel()

        XCTAssertEqual(viewModel.localSpeechModelState, .notInstalled)
        XCTAssertEqual(viewModel.statusMessage, "高精度语音包已删除")
        XCTAssertNil(manager.installedModelURL())
    }

    func testCheckHighAccuracySpeechModelUpdatePublishesStatusAndMessage() async {
        let context = makeContext()
        defer { context.cleanup() }

        let updateChecker = MockSpeechModelUpdateChecker(
            status: .upToDate(version: "2024-09-30")
        )
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelUpdateChecker: updateChecker
        )

        await viewModel.checkHighAccuracySpeechModelUpdate()

        XCTAssertEqual(updateChecker.checkCallCount, 1)
        XCTAssertEqual(viewModel.localSpeechModelUpdateStatus, .upToDate(version: "2024-09-30"))
        XCTAssertFalse(viewModel.isCheckingSpeechModelUpdate)
        XCTAssertEqual(viewModel.statusMessage, "高精度语音包已是当前推荐版本（2024-09-30）")
    }

    func testAvailableSpeechModelUpdateDownloadsRecommendedManifest() async throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        try context.writeSpeechModelDirectory()
        let latestManifest = LocalSpeechModelManifest(
            fileName: "openai_whisper-large-v3-v20250101_626MB",
            modelName: "large-v3-v20250101_626MB",
            version: "2025-01-01",
            sizeDescription: "约 626 MiB"
        )
        let installer = MockSettingsModelInstaller(progressValues: [1])
        let updateChecker = MockSpeechModelUpdateChecker(
            status: .updateAvailable(currentVersion: "2024-09-30", latestManifest: latestManifest)
        )
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager,
            localSpeechModelInstaller: installer,
            localSpeechModelUpdateChecker: updateChecker
        )
        viewModel.isIdlePrewarmEnabled = false

        await viewModel.checkHighAccuracySpeechModelUpdate()
        await viewModel.downloadHighAccuracySpeechModel()

        XCTAssertEqual(installer.lastInstalledManifest, latestManifest)
        XCTAssertEqual(manager.installedManifest(), latestManifest)
        XCTAssertEqual(viewModel.localSpeechModelUpdateStatus, .upToDate(version: "2025-01-01"))
    }

    func testDeleteHighAccuracySpeechModelResetsUpdateStatus() throws {
        let context = makeContext()
        defer { context.cleanup() }

        let manager = context.makeLocalSpeechModelManager()
        try context.writeSpeechModelDirectory()
        let updateChecker = MockSpeechModelUpdateChecker(
            status: .upToDate(version: "2024-09-30")
        )
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            localSpeechModelManager: manager,
            localSpeechModelUpdateChecker: updateChecker
        )

        try viewModel.deleteHighAccuracySpeechModel()

        XCTAssertEqual(viewModel.localSpeechModelUpdateStatus, .notInstalled)
    }

    func testLoadReflectsSavedUserVocabularyEntries() throws {
        let context = makeContext()
        defer { context.cleanup() }
        let vocabularyStore = context.makeUserVocabularyStore()
        _ = try vocabularyStore.add(value: "ReadyWOD", kind: .project, aliases: ["ready wod"])

        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            userVocabularyStore: vocabularyStore
        )

        XCTAssertEqual(viewModel.userVocabularyEntries.map(\.value), ["ReadyWOD"])
    }

    func testAddUserVocabularyEntryPersistsAndRefreshesList() throws {
        let context = makeContext()
        defer { context.cleanup() }
        let vocabularyStore = context.makeUserVocabularyStore()
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            userVocabularyStore: vocabularyStore
        )
        viewModel.newVocabularyText = " 张三 "
        viewModel.selectedVocabularyKind = .person

        try viewModel.addUserVocabularyEntry()

        XCTAssertEqual(viewModel.userVocabularyEntries.map(\.value), ["张三"])
        XCTAssertEqual(viewModel.userVocabularyEntries.first?.kind, .person)
        XCTAssertEqual(viewModel.newVocabularyText, "")
        XCTAssertEqual(viewModel.statusMessage, "常用词已添加")
        XCTAssertEqual(try vocabularyStore.load().map(\.value), ["张三"])
    }

    func testExternalUserVocabularyChangeRefreshesList() async throws {
        let context = makeContext()
        defer { context.cleanup() }
        let vocabularyStore = context.makeUserVocabularyStore()
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            userVocabularyStore: vocabularyStore
        )

        _ = try vocabularyStore.add(value: "ReadyType", kind: .product, aliases: ["ReadyTap"])
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertEqual(viewModel.userVocabularyEntries.map(\.value), ["ReadyType"])
        XCTAssertEqual(viewModel.userVocabularyEntries.first?.aliases, ["ReadyTap"])
    }

    func testImportUserVocabularyEntriesPersistsOneTermPerLine() throws {
        let context = makeContext()
        defer { context.cleanup() }
        let vocabularyStore = context.makeUserVocabularyStore()
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            userVocabularyStore: vocabularyStore
        )
        viewModel.importVocabularyText = "ReadyType\n\nDeepSeek"
        viewModel.selectedVocabularyKind = .product

        try viewModel.importUserVocabularyEntries()

        XCTAssertEqual(viewModel.userVocabularyEntries.map(\.value), ["ReadyType", "DeepSeek"])
        XCTAssertEqual(viewModel.importVocabularyText, "")
        XCTAssertEqual(viewModel.statusMessage, "已导入 2 个常用词")
    }

    func testDeleteUserVocabularyEntryPersistsAndRefreshesList() throws {
        let context = makeContext()
        defer { context.cleanup() }
        let vocabularyStore = context.makeUserVocabularyStore()
        let entry = try XCTUnwrap(vocabularyStore.add(value: "ReadyPlay", kind: .project))
        let viewModel = SettingsViewModel(
            settingsStore: SettingsStore(defaults: context.defaults),
            keychainService: context.keychain,
            userVocabularyStore: vocabularyStore
        )

        try viewModel.deleteUserVocabularyEntry(id: entry.id)

        XCTAssertEqual(viewModel.userVocabularyEntries, [])
        XCTAssertEqual(try vocabularyStore.load(), [])
        XCTAssertEqual(viewModel.statusMessage, "常用词已删除")
    }

    private func makeContext() -> TestContext {
        let suiteName = "ReadyTypeSettingsViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TestContext(
            suiteName: suiteName,
            defaults: defaults,
            keychain: InMemoryAPIKeyStore()
        )
    }
}

private final class MockSettingsConnectionProvider: ChatCompletionProvider {
    let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func complete(systemPrompt: String, userText: String) async throws -> String {
        try result.get()
    }
}

@MainActor
private final class MockSettingsModelInstaller: LocalSpeechModelInstalling {
    private let progressValues: [Double]
    private(set) var installCallCount = 0
    private(set) var lastInstalledManifest: LocalSpeechModelManifest?

    init(progressValues: [Double]) {
        self.progressValues = progressValues
    }

    func installModel(
        _ manifest: LocalSpeechModelManifest,
        using manager: LocalSpeechModelManager,
        progress: @escaping (Double) -> Void
    ) async throws {
        installCallCount += 1
        lastInstalledManifest = manifest
        for value in progressValues {
            progress(value)
        }

        let destinationURL = manager.destinationURL(for: manifest)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: destinationURL.appendingPathComponent("TextDecoder.mlmodelc"))
    }
}

private final class InMemoryAPIKeyStore: APIKeyStoring {
    private var values: [String: String] = [:]

    func saveAPIKey(_ apiKey: String, account: String) throws {
        values[account] = apiKey
    }

    func loadAPIKey(account: String) throws -> String? {
        values[account]
    }

    func hasAPIKey(account: String) throws -> Bool {
        values[account] != nil
    }

    func deleteAPIKey(account: String) throws {
        values.removeValue(forKey: account)
    }
}

private final class MockSpeechModelUpdateChecker: LocalSpeechModelUpdateChecking {
    private let status: LocalSpeechModelUpdateStatus
    private(set) var checkCallCount = 0

    init(status: LocalSpeechModelUpdateStatus) {
        self.status = status
    }

    func checkForUpdates() async -> LocalSpeechModelUpdateStatus {
        checkCallCount += 1
        return status
    }
}

private struct TestContext {
    let suiteName: String
    let defaults: UserDefaults
    let keychain: InMemoryAPIKeyStore
    let speechModelsDirectory: URL
    let userVocabularyFileURL: URL

    init(suiteName: String, defaults: UserDefaults, keychain: InMemoryAPIKeyStore) {
        self.suiteName = suiteName
        self.defaults = defaults
        self.keychain = keychain
        self.speechModelsDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeSettingsSpeechModels-\(UUID().uuidString)")
        self.userVocabularyFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadyTypeSettingsUserVocabulary-\(UUID().uuidString)")
            .appendingPathComponent("UserVocabulary.json")
    }

    func cleanup() {
        try? keychain.deleteAPIKey()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: speechModelsDirectory)
        try? FileManager.default.removeItem(at: userVocabularyFileURL.deletingLastPathComponent())
    }

    func makeLocalSpeechModelManager() -> LocalSpeechModelManager {
        LocalSpeechModelManager(modelsDirectory: speechModelsDirectory)
    }

    func makeUserVocabularyStore() -> UserVocabularyStore {
        UserVocabularyStore(fileURL: userVocabularyFileURL)
    }

    func writeSpeechModelDirectory() throws {
        let modelDirectory = speechModelsDirectory.appendingPathComponent(LocalSpeechModelManager.defaultWhisperKitModelFolderName)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: modelDirectory.appendingPathComponent("TextDecoder.mlmodelc"))
    }
}
