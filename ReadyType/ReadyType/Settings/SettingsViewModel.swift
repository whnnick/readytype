import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    typealias PostDownloadPrewarm = @MainActor () async -> LocalSpeechModelState
    typealias VoiceShortcutChangeHandler = @MainActor (VoiceShortcutConfiguration) -> Void

    @Published var defaultMode: OutputMode
    @Published var baseURLText: String
    @Published var model: String
    @Published var pasteAutomatically: Bool
    @Published var speechRecognitionMode: SpeechRecognitionMode
    @Published var isHighAccuracyRecognitionEnabled: Bool
    @Published var isIdlePrewarmEnabled: Bool
    @Published var isVocabularyLearningSuggestionsEnabled: Bool
    @Published var voiceShortcut: VoiceShortcutConfiguration
    @Published var apiKeyText: String
    @Published private(set) var hasSavedAPIKey: Bool
    @Published private(set) var statusMessage: String?
    @Published private(set) var apiConnectionTestState: APIConnectionTestState
    @Published private(set) var isTestingAPIConnection: Bool
    @Published private(set) var localSpeechModelState: LocalSpeechModelState
    @Published private(set) var isDownloadingSpeechModel: Bool
    @Published private(set) var userVocabularyEntries: [UserVocabularyEntry]
    @Published var newVocabularyText: String
    @Published var importVocabularyText: String
    @Published var selectedVocabularyKind: UserVocabularyKind

    private let settingsStore: SettingsStore
    private let keychainService: APIKeyStoring
    private let apiConnectionTester: APIConnectionTester
    private let localSpeechModelManager: LocalSpeechModelManager
    private let localSpeechModelInstaller: LocalSpeechModelInstalling
    private let userVocabularyStore: UserVocabularyStore
    private let postDownloadPrewarm: PostDownloadPrewarm?
    private let onVoiceShortcutChange: VoiceShortcutChangeHandler?
    private var userVocabularyCancellables: Set<AnyCancellable> = []

    init(
        settingsStore: SettingsStore = SettingsStore(),
        keychainService: APIKeyStoring = KeychainService(),
        apiConnectionTester: APIConnectionTester = APIConnectionTester(),
        localSpeechModelManager: LocalSpeechModelManager = LocalSpeechModelManager(),
        localSpeechModelInstaller: LocalSpeechModelInstalling = CoreMLSpeechModelInstaller(),
        userVocabularyStore: UserVocabularyStore = UserVocabularyStore(),
        postDownloadPrewarm: PostDownloadPrewarm? = nil,
        onVoiceShortcutChange: VoiceShortcutChangeHandler? = nil
    ) {
        self.settingsStore = settingsStore
        self.keychainService = keychainService
        self.apiConnectionTester = apiConnectionTester
        self.localSpeechModelManager = localSpeechModelManager
        self.localSpeechModelInstaller = localSpeechModelInstaller
        self.userVocabularyStore = userVocabularyStore
        self.postDownloadPrewarm = postDownloadPrewarm
        self.onVoiceShortcutChange = onVoiceShortcutChange

        let settings = settingsStore.load()
        self.defaultMode = settings.defaultMode
        self.baseURLText = settings.deepSeekBaseURL.absoluteString
        self.model = settings.deepSeekModel
        self.pasteAutomatically = settings.pasteAutomatically
        self.speechRecognitionMode = settings.speechRecognitionMode
        self.isHighAccuracyRecognitionEnabled = settings.isHighAccuracyRecognitionEnabled
        self.isIdlePrewarmEnabled = settings.isIdlePrewarmEnabled
        self.isVocabularyLearningSuggestionsEnabled = settings.isVocabularyLearningSuggestionsEnabled
        self.voiceShortcut = settings.voiceShortcut
        self.apiKeyText = ""
        self.hasSavedAPIKey = (try? keychainService.hasAPIKey()) ?? false
        self.statusMessage = nil
        self.apiConnectionTestState = .notTested
        self.isTestingAPIConnection = false
        self.localSpeechModelState = localSpeechModelManager.state()
        self.isDownloadingSpeechModel = false
        self.userVocabularyEntries = (try? userVocabularyStore.load()) ?? []
        self.newVocabularyText = ""
        self.importVocabularyText = ""
        self.selectedVocabularyKind = .general
        NotificationCenter.default.publisher(for: .readyTypeUserVocabularyDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                let changedFileURL = notification.userInfo?[UserVocabularyStore.changedFileURLUserInfoKey] as? URL
                Task { @MainActor in
                    self?.reloadUserVocabularyEntriesIfNeeded(changedFileURL: changedFileURL)
                }
            }
            .store(in: &userVocabularyCancellables)
    }

    func save() throws {
        let baseURL = try validatedBaseURL()
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousShortcut = settingsStore.load().voiceShortcut

        guard !trimmedModel.isEmpty else {
            throw ReadyTypeError.invalidSettings("模型不能为空。")
        }

        let settings = AppSettings(
            defaultMode: defaultMode,
            deepSeekBaseURL: baseURL,
            deepSeekModel: trimmedModel,
            pasteAutomatically: pasteAutomatically,
            speechRecognitionMode: speechRecognitionMode,
            isHighAccuracyRecognitionEnabled: isHighAccuracyRecognitionEnabled,
            isIdlePrewarmEnabled: isIdlePrewarmEnabled,
            isVocabularyLearningSuggestionsEnabled: isVocabularyLearningSuggestionsEnabled,
            voiceShortcut: voiceShortcut
        )

        settingsStore.save(settings)

        let trimmedAPIKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedAPIKey.isEmpty {
            try keychainService.saveAPIKey(trimmedAPIKey)
            apiKeyText = ""
            hasSavedAPIKey = true
        }

        statusMessage = "设置已保存"

        if previousShortcut != voiceShortcut {
            onVoiceShortcutChange?(voiceShortcut)
        }
    }

    func setVocabularyLearningSuggestionsEnabled(_ enabled: Bool) {
        isVocabularyLearningSuggestionsEnabled = enabled

        var settings = settingsStore.load()
        settings.isVocabularyLearningSuggestionsEnabled = enabled
        settingsStore.save(settings)
        statusMessage = enabled ? "已开启常用词建议" : "已关闭常用词建议"
    }

    func clearAPIKey() throws {
        try keychainService.deleteAPIKey()
        apiKeyText = ""
        hasSavedAPIKey = false
        statusMessage = "DeepSeek 密钥已清除"
        apiConnectionTestState = .notTested
    }

    func testAPIConnection() async {
        guard !isTestingAPIConnection else {
            return
        }

        isTestingAPIConnection = true
        apiConnectionTestState = .testing
        defer { isTestingAPIConnection = false }

        do {
            let baseURL = try validatedBaseURL()
            let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedModel.isEmpty else {
                apiConnectionTestState = APIConnectionTestState(
                    status: .modelUnavailable,
                    detail: "模型不能为空，请填写 DeepSeek 模型名。",
                    model: nil,
                    latencyMilliseconds: nil
                )
                return
            }

            let typedAPIKey = apiKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
            let apiKey = typedAPIKey.isEmpty ? (try keychainService.loadAPIKey() ?? "") : typedAPIKey

            apiConnectionTestState = await apiConnectionTester.testConnection(
                baseURL: baseURL,
                model: trimmedModel,
                apiKey: apiKey
            )
        } catch let error as ReadyTypeError {
            let status: APIConnectionTestStatus
            if case .invalidSettings = error {
                status = .networkFailed
            } else {
                status = .unknownFailure
            }
            apiConnectionTestState = APIConnectionTestState(
                status: status,
                detail: error.userMessage,
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                latencyMilliseconds: nil
            )
        } catch {
            apiConnectionTestState = APIConnectionTestState(
                status: .unknownFailure,
                detail: "测试失败，请稍后重试。",
                model: model.trimmingCharacters(in: .whitespacesAndNewlines),
                latencyMilliseconds: nil
            )
        }
    }

    func downloadHighAccuracySpeechModel() async {
        guard !isDownloadingSpeechModel else {
            return
        }

        isDownloadingSpeechModel = true
        defer { isDownloadingSpeechModel = false }

        let service = LocalSpeechModelDownloadService(
            manager: localSpeechModelManager,
            installer: localSpeechModelInstaller,
            onStateChange: { [weak self] state in
                Task { @MainActor in
                    self?.localSpeechModelState = state
                }
            }
        )

        let finalState = await service.downloadDefaultModel()
        localSpeechModelState = finalState

        switch finalState {
        case .downloadedCold, .warm:
            await prewarmAfterDownloadIfAllowed(from: finalState)
        case .failed:
            statusMessage = finalState.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
        case .notInstalled, .downloading, .warming:
            break
        }
    }

    func deleteHighAccuracySpeechModel() throws {
        try localSpeechModelManager.deleteInstalledModels()
        localSpeechModelState = localSpeechModelManager.state()
        statusMessage = "高精度语音包已删除"
    }

    func addUserVocabularyEntry() throws {
        guard try userVocabularyStore.add(
            value: newVocabularyText,
            kind: selectedVocabularyKind
        ) != nil else {
            statusMessage = "常用词已存在或为空"
            return
        }

        newVocabularyText = ""
        try reloadUserVocabularyEntries()
        statusMessage = "常用词已添加"
    }

    func importUserVocabularyEntries() throws {
        let imported = try userVocabularyStore.importLines(
            importVocabularyText,
            kind: selectedVocabularyKind
        )
        guard !imported.isEmpty else {
            statusMessage = "没有可导入的常用词"
            return
        }

        importVocabularyText = ""
        try reloadUserVocabularyEntries()
        statusMessage = "已导入 \(imported.count) 个常用词"
    }

    func deleteUserVocabularyEntry(id: UUID) throws {
        try userVocabularyStore.delete(id: id)
        try reloadUserVocabularyEntries()
        statusMessage = "常用词已删除"
    }

    private func validatedBaseURL() throws -> URL {
        guard let url = URL(string: baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil
        else {
            throw ReadyTypeError.invalidSettings("服务地址必须是有效的 http(s) 地址。")
        }

        return url
    }

    private func reloadUserVocabularyEntries() throws {
        userVocabularyEntries = try userVocabularyStore.load()
    }

    private func reloadUserVocabularyEntriesIfNeeded(changedFileURL: URL?) {
        guard changedFileURL == userVocabularyStore.storageURL else {
            return
        }

        try? reloadUserVocabularyEntries()
    }

    private func prewarmAfterDownloadIfAllowed(from state: LocalSpeechModelState) async {
        guard state == .downloadedCold else {
            statusMessage = LocalSpeechModelState.warm.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
            return
        }

        guard isHighAccuracyRecognitionEnabled, isIdlePrewarmEnabled, let postDownloadPrewarm else {
            statusMessage = LocalSpeechModelState.downloadedCold.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
            return
        }

        localSpeechModelState = .warming
        statusMessage = LocalSpeechModelState.warming.readyTypeDisplayMessage(isHighAccuracyEnabled: true)

        let warmupState = await postDownloadPrewarm()
        localSpeechModelState = warmupState

        switch warmupState {
        case .warm:
            statusMessage = warmupState.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
        case .failed:
            statusMessage = warmupState.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
        case .downloadedCold:
            statusMessage = warmupState.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
        case .notInstalled, .downloading, .warming:
            statusMessage = warmupState.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
        }
    }
}
