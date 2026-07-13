import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private let settingsStore = SettingsStore()
    private let usageStatisticsStore = UsageStatisticsStore()
    private lazy var analyticsTracker: AnalyticsTracking = ConsentAwareAnalyticsTracker(
        tracker: ReadyTypeAnalyticsFactory.make(),
        isEnabled: { [settingsStore] in settingsStore.load().isAnonymousAnalyticsEnabled }
    )
    private let keychainService = KeychainService()
    private var menuBarController: MenuBarController?
    private var voiceInputController: VoiceInputController?
    private var shortcutService: GlobalShortcutService?
    private var textDelivery: TextDelivering?
    private var escapeKeyCancelMonitor: EscapeKeyCancelMonitor?
    private var settingsWindow: NSWindow?
    private var commandObservers: [NSObjectProtocol] = []
    private var stateObservers: Set<AnyCancellable> = []
    private var recordingHUDWindowController: RecordingHUDWindowController?
    private var autoFinishRecordingTask: Task<Void, Never>?
    private var idlePrewarmController: IdlePrewarmController?
    private let maximumRecordingDuration = RecordingPolicy.defaultMaximumDuration
    private let pasteTargetActivator = SystemPasteTargetActivator()
    private let localSpeechModelManager = LocalSpeechModelManager()
    private let userVocabularyStore = UserVocabularyStore(
        fileURL: AppDiagnostics.debugVocabularyFileURL() ?? UserVocabularyStore.defaultFileURL()
    )
    private lazy var highAccuracySpeechEngine = CoreMLHighAccuracySpeechEngine(modelManager: localSpeechModelManager)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        applySavedAppearance()
        configureApplicationIcon()
        syncAppStateWithSettings()
        analyticsTracker.track(
            .appLaunched(
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
                build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
                osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
                architecture: .current
            )
        )
        menuBarController = MenuBarController(appState: appState) { [weak self] in
            self?.showSettingsWindow()
        }
        recordingHUDWindowController = RecordingHUDWindowController(appState: appState)
        configureVoicePipeline()
        observeVoiceInputCommands()
        if AppDiagnostics.isDebugInsertEnabled() {
            observeDebugInsertCommand()
        }
        if AppDiagnostics.isDebugHUDEnabled() {
            observeDebugHUDCommand()
        }
        if AppDiagnostics.isDebugVocabularyEnabled() {
            observeDebugVocabularyCommand()
            seedDebugVocabularyIfRequested()
        }
        observeRuntimeStateForHUD()
        if !AppDiagnostics.shouldSuppressLaunchWindow() {
            showSettingsWindow()
        }
        startGlobalShortcut()
        startIdlePrewarmIfConfigured()
    }

    private func applySavedAppearance() {
        let rawValue = UserDefaults.standard.string(forKey: "readyTypeAppearance")
        switch ReadyTypeAppearance(rawValue: rawValue ?? ReadyTypeAppearance.system.rawValue) ?? .system {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    private func syncAppStateWithSettings() {
        let settings = settingsStore.load()
        appState.selectedMode = settings.defaultMode
        appState.speechRecognitionMode = settings.speechRecognitionMode
        appState.isHighAccuracyRecognitionEnabled = settings.isHighAccuracyRecognitionEnabled
        appState.voiceShortcut = settings.voiceShortcut
        appState.localSpeechModelState = currentLocalSpeechModelState(isHighAccuracyEnabled: settings.isHighAccuracyRecognitionEnabled)
    }

    private func startIdlePrewarmIfConfigured() {
        let settings = settingsStore.load()
        let isHighAccuracyRecognitionEnabled = settings.isHighAccuracyRecognitionEnabled
        let isIdlePrewarmEnabled = settings.isIdlePrewarmEnabled
        let warmupService = LocalSpeechModelWarmupService(
            initialState: settings.isHighAccuracyRecognitionEnabled ? localSpeechModelManager.state() : .notInstalled,
            policy: LocalSpeechModelWarmupPolicy(
                isHighAccuracyRecognitionEnabled: {
                    isHighAccuracyRecognitionEnabled
                },
                isIdlePrewarmEnabled: {
                    isIdlePrewarmEnabled
                },
                isRecording: {
                    false
                },
                isLowPowerModeEnabled: {
                    ProcessInfo.processInfo.isLowPowerModeEnabled
                },
                isSystemUnderPressure: {
                    ProcessInfo.processInfo.thermalState == .serious ||
                        ProcessInfo.processInfo.thermalState == .critical
                }
            ),
            warmup: { [highAccuracySpeechEngine] in
                try await highAccuracySpeechEngine.prewarm()
            }
        )
        let controller = IdlePrewarmController(
            warmupService: warmupService,
            isRecording: { [appState] in
                await MainActor.run {
                    appState.runtimeState == .recording
                }
            },
            onStateChange: { [weak self] state in
                self?.handlePrewarmStateChange(state)
            }
        )

        idlePrewarmController = controller
        controller.start()
    }

    private func configureApplicationIcon() {
        guard let url = Self.resourceURL(forResource: "ReadyTypeAppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: url)
        else {
            return
        }

        NSApp.applicationIconImage = icon
    }

    private static func resourceURL(forResource name: String, withExtension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutService?.stop()
        escapeKeyCancelMonitor?.stop()
        autoFinishRecordingTask?.cancel()
        idlePrewarmController?.cancel()
        commandObservers.forEach(NotificationCenter.default.removeObserver)
        stateObservers.removeAll()
        recordingHUDWindowController?.hideImmediately()
        DistributedNotificationCenter.default().removeObserver(self)
        commandObservers.removeAll()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settingsWindow?.isVisible != true {
            showSettingsWindow()
        }
        return true
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            localSpeechModelManager: localSpeechModelManager,
            userVocabularyStore: userVocabularyStore,
            postDownloadPrewarm: { [weak self] in
                await self?.prewarmHighAccuracySpeechModelAfterDownload() ?? .failed(reason: "应用状态不可用")
            },
            onVoiceShortcutChange: { [weak self] shortcut in
                self?.appState.voiceShortcut = shortcut
                self?.restartGlobalShortcut()
            }
        )
    }

    private func configureVoicePipeline() {
        let outputProcessor = OutputProcessor(
            providerFactory: { [settingsStore, keychainService] in
                let settings = settingsStore.load()
                let apiKey = (try? keychainService.loadAPIKey()) ?? ""

                return DeepSeekProvider(
                    configuration: DeepSeekConfiguration(
                        baseURL: settings.deepSeekBaseURL,
                        endpointPath: DeepSeekConfiguration.default.endpointPath,
                        model: settings.deepSeekModel,
                        timeoutSeconds: DeepSeekConfiguration.default.timeoutSeconds
                    ),
                    apiKey: apiKey
                )
            },
            termCorrectionServiceProvider: { [weak self] in
                let dictionary = self?.currentSmartTermDictionary() ?? .readyTypeDefault
                return TermCorrectionService(dictionary: dictionary)
            },
            directDictationNormalizerProvider: { [weak self] in
                let dictionary = self?.currentSmartTermDictionary() ?? .readyTypeDefault
                return DirectDictationNormalizer(dictionary: dictionary)
            },
            userVocabularyTermsProvider: { [weak self] in
                ((try? self?.userVocabularyStore.load()) ?? []).map(\.value)
            }
        )
        let textDelivery = PasteService(pasteTargetActivator: pasteTargetActivator)
        self.textDelivery = textDelivery

        let workflowController = WorkflowController(
            appState: appState,
            settingsProvider: { [settingsStore] in settingsStore.load() },
            outputProcessor: outputProcessor,
            textDelivery: textDelivery,
            outputContextProvider: { [appState] transcript in
                let context = ForegroundContextService().currentContext()
                let scenario = appState.scenarioSelection.manualScenario
                    ?? OutputScenario.infer(
                        bundleIdentifier: context.bundleIdentifier,
                        windowTitle: context.windowTitle,
                        transcript: transcript
                    )
                return OutputContext(
                    scenario: scenario,
                    chatTone: ChatTone.infer(
                        bundleIdentifier: context.bundleIdentifier,
                        windowTitle: context.windowTitle
                    )
                )
            },
            vocabularySuggestionProvider: { [weak self] transcript, output, outputContext in
                guard let self else {
                    return []
                }

                let entries = (try? self.userVocabularyStore.load()) ?? []
                return UserVocabularySuggestionService(dictionary: self.currentSmartTermDictionary())
                    .suggestions(
                        transcript: transcript,
                        finalText: output.finalText,
                        scenario: outputContext.scenario,
                        existingEntries: entries
                    )
            },
            usageStatisticsRecorder: usageStatisticsStore,
            analyticsTracker: analyticsTracker
        )

        voiceInputController = VoiceInputController(
            appState: appState,
            permissionService: PermissionService(),
            recorder: AudioRecorderService(),
            transcriber: SpeechTranscriptionService(
                recordingBackend: RoutedSpeechRecognitionBackend(
                    highAccuracyBackend: LocalHighAccuracySpeechBackend(engine: highAccuracySpeechEngine),
                    contextProvider: { [weak self] recording in
                        self?.speechRecognitionRouteContext(for: recording) ?? RoutedSpeechRecognitionBackend.defaultContext(for: recording)
                    },
                    onDecision: { [weak self] decision in
                        self?.handleSpeechRecognitionRouteDecision(decision)
                    }
                )
            ),
            transcriptHandler: workflowController,
            analyticsTracker: analyticsTracker
        )
    }

    private func speechRecognitionRouteContext(for recording: AudioRecording) -> SpeechRecognitionRouteContext {
        let settings = settingsStore.load()
        let foregroundContext = ForegroundContextService().currentContext()
        let scenario = appState.scenarioSelection.manualScenario
            ?? OutputScenario.infer(
                bundleIdentifier: foregroundContext.bundleIdentifier,
                windowTitle: foregroundContext.windowTitle
            )
        let localModelState = currentLocalSpeechModelState(isHighAccuracyEnabled: settings.isHighAccuracyRecognitionEnabled)
        let contextualVocabularyProvider = ContextualVocabularyProvider(dictionary: currentSmartTermDictionary())
        let contextualTerms = contextualVocabularyProvider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: scenario,
                frontmostAppBundleIdentifier: foregroundContext.bundleIdentifier,
                projectRoot: nil,
                transcriptPrefix: "",
                maximumTerms: 80,
                timeoutMilliseconds: 80
            )
        )

        appState.speechRecognitionMode = settings.speechRecognitionMode
        appState.isHighAccuracyRecognitionEnabled = settings.isHighAccuracyRecognitionEnabled
        appState.localSpeechModelState = localModelState

        return SpeechRecognitionRouteContext(
            mode: settings.speechRecognitionMode,
            scenario: scenario,
            frontmostAppBundleIdentifier: foregroundContext.bundleIdentifier,
            recordingDuration: recording.duration,
            hasLowConfidenceSignal: false,
            hasChineseMisclassifiedAsEnglishSignal: false,
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            localModelState: localModelState,
            contextualTerms: contextualTerms
        )
    }

    private func currentSmartTermDictionary() -> SmartTermDictionary {
        let entries = (try? userVocabularyStore.load()) ?? []
        return SmartTermDictionary.readyTypeDefault.mergingUserVocabulary(entries)
    }

    private func currentLocalSpeechModelState(isHighAccuracyEnabled: Bool) -> LocalSpeechModelState {
        guard isHighAccuracyEnabled else {
            return .notInstalled
        }

        return LocalSpeechModelReadiness.displayState(
            diskState: localSpeechModelManager.state(),
            runtimeState: appState.localSpeechModelState
        )
    }

    private func handleSpeechRecognitionRouteDecision(_ decision: SpeechRecognitionRouteDecision) {
        appState.lastSpeechRecognitionRouteDecision = decision

        guard decision.backend == .highAccuracyLocal, decision.fallbackReason == nil else {
            return
        }

        appState.localSpeechModelState = .warm
    }

    private func observeDebugInsertCommand() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDebugInsertNotification(_:)),
            name: .readyTypeDebugInsertRequested,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    private func observeDebugHUDCommand() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDebugHUDNotification(_:)),
            name: .readyTypeDebugHUDRequested,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    private func observeDebugVocabularyCommand() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleDebugVocabularyNotification(_:)),
            name: .readyTypeDebugVocabularyRequested,
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    private func seedDebugVocabularyIfRequested() {
        guard let value = AppDiagnostics.debugVocabularyValue() else {
            return
        }

        addVocabularySuggestion(
            value: value,
            kind: UserVocabularyKind.product.rawValue,
            aliases: ["ReadyType UI Gate"]
        )
    }

    @objc private func handleDebugInsertNotification(_ notification: Notification) {
        InjectionDiagnostics.log("debug insert notification received")
        guard let text = notification.userInfo?["text"] as? String, !text.isEmpty else {
            InjectionDiagnostics.log("debug insert missing text")
            return
        }

        do {
            pasteTargetActivator.captureCurrentTarget()
            let result = try textDelivery?.deliver(text, pasteAutomatically: true)
            appState.runtimeState = result == .pasted ? .pasted : .copiedFallback
            appState.lastMessage = result == .pasted ? "诊断文本已插入" : "诊断文本已复制到剪贴板"
            appState.lastOutput = text
            appState.lastProcessingSummary = "诊断：直接测试文本注入链路"
        } catch let error as ReadyTypeError {
            appState.runtimeState = .error(error.userMessage)
            appState.lastMessage = error.userMessage
        } catch {
            let readyTypeError = ReadyTypeError.pasteFailed
            appState.runtimeState = .error(readyTypeError.userMessage)
            appState.lastMessage = readyTypeError.userMessage
        }
    }

    @objc private func handleDebugHUDNotification(_ notification: Notification) {
        guard let stateName = notification.userInfo?["state"] as? String else {
            return
        }

        let message = notification.userInfo?["message"] as? String
        appState.lastMessage = message

        switch stateName {
        case "idle":
            appState.runtimeState = .idle
        case "recording":
            appState.runtimeState = .recording
        case "transcribing":
            appState.runtimeState = .transcribing
        case "processingAI":
            appState.runtimeState = .processingAI
        case "pasted":
            appState.runtimeState = .pasted
        case "copiedFallback":
            appState.runtimeState = .copiedFallback
        case "error":
            appState.runtimeState = .error(message ?? ReadyTypeError.pasteFailed.userMessage)
        default:
            return
        }
    }

    @objc private func handleDebugVocabularyNotification(_ notification: Notification) {
        let value = notification.userInfo?["value"] as? String
        let aliases = notification.userInfo?["aliases"] as? [String] ?? []
        let rawKind = notification.userInfo?["kind"] as? String
        addVocabularySuggestion(value: value, kind: rawKind, aliases: aliases)
    }

    private func startGlobalShortcut() {
        let settings = settingsStore.load()
        let shortcutService = GlobalShortcutService(
            configuration: settings.voiceShortcut,
            onToggle: { [weak self] in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
        )

        do {
            try shortcutService.start()
            self.shortcutService = shortcutService
        } catch let error as ReadyTypeError {
            appState.runtimeState = .error(error.userMessage)
            appState.lastMessage = error.userMessage
        } catch {
            let readyTypeError = ReadyTypeError.shortcutRegistrationFailed
            appState.runtimeState = .error(readyTypeError.userMessage)
            appState.lastMessage = readyTypeError.userMessage
        }
    }

    private func restartGlobalShortcut() {
        shortcutService?.stop()
        shortcutService = nil
        startGlobalShortcut()
    }

    private func startEscapeKeyCancelMonitor() {
        let monitor = EscapeKeyCancelMonitor { [weak self] in
            Task { @MainActor in
                self?.cancelRecording()
            }
        }

        do {
            try monitor.start()
            escapeKeyCancelMonitor = monitor
        } catch ReadyTypeError.keyboardMonitoringPermissionMissing {
            escapeKeyCancelMonitor = nil
            appState.lastMessage = "正在语音输入。Esc 取消需要辅助功能权限。"
        } catch let error as ReadyTypeError {
            escapeKeyCancelMonitor = nil
            appState.lastMessage = error.userMessage
        } catch {
            escapeKeyCancelMonitor = nil
            let readyTypeError = ReadyTypeError.shortcutRegistrationFailed
            appState.lastMessage = readyTypeError.userMessage
        }
    }

    private func cancelRecording() {
        guard appState.runtimeState == .recording else {
            return
        }

        autoFinishRecordingTask?.cancel()
        autoFinishRecordingTask = nil
        escapeKeyCancelMonitor?.stop()
        escapeKeyCancelMonitor = nil
        voiceInputController?.cancelRecording()
    }

    private func observeVoiceInputCommands() {
        let center = NotificationCenter.default
        commandObservers.append(
            center.addObserver(
                forName: .readyTypeToggleRecordingRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.toggleRecording()
                }
            }
        )
        commandObservers.append(
            center.addObserver(
                forName: .readyTypeBeginRecordingRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.pasteTargetActivator.captureCurrentTarget()
                    await self?.beginRecording()
                }
            }
        )
        commandObservers.append(
            center.addObserver(
                forName: .readyTypeFinishRecordingRequested,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    await self?.finishRecording()
                }
            }
        )
        commandObservers.append(
            center.addObserver(
                forName: .readyTypeAddVocabularySuggestionRequested,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let value = notification.userInfo?["value"] as? String
                let aliases = notification.userInfo?["aliases"] as? [String] ?? []
                let rawKind = notification.userInfo?["kind"] as? String
                let rawScopes = notification.userInfo?["scopes"] as? [String] ?? []
                let confidence = notification.userInfo?["confidence"] as? Double ?? 0.82
                Task { @MainActor in
                    self?.confirmVocabularySuggestion(
                        value: value,
                        kind: rawKind,
                        aliases: aliases,
                        scopes: rawScopes,
                        confidence: confidence
                    )
                }
            }
        )
        commandObservers.append(
            center.addObserver(
                forName: .readyTypeIgnoreVocabularySuggestionRequested,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                let value = notification.userInfo?["value"] as? String
                let aliases = notification.userInfo?["aliases"] as? [String] ?? []
                Task { @MainActor in
                    self?.ignoreVocabularySuggestion(value: value, aliases: aliases)
                }
            }
        )
    }

    private func addVocabularySuggestion(value: String?, kind rawKind: String?, aliases: [String]) {
        guard let value else {
            return
        }

        let kind = rawKind.flatMap(UserVocabularyKind.init(rawValue:)) ?? .general

        do {
            let entry = try userVocabularyStore.add(value: value, kind: kind, aliases: aliases)
            removeVocabularySuggestion(value: value)
            appState.lastMessage = entry == nil ? "常用词已存在" : "已加入常用词"
        } catch {
            appState.lastMessage = "常用词保存失败"
        }
    }

    private func confirmVocabularySuggestion(
        value: String?,
        kind rawKind: String?,
        aliases: [String],
        scopes rawScopes: [String],
        confidence: Double
    ) {
        guard let value else {
            return
        }

        let kind = rawKind.flatMap(UserVocabularyKind.init(rawValue:)) ?? .general
        let scopes = rawScopes.compactMap(UserVocabularyScope.init(rawValue:))
        let alias = aliases.first ?? ""

        do {
            let entry = try userVocabularyStore.confirmSuggestion(
                value: value,
                alias: alias,
                kind: kind,
                scopes: scopes.isEmpty ? [.all] : scopes,
                confidence: confidence
            )
            removeVocabularySuggestion(value: value)
            appState.lastMessage = entry == nil ? "常用词已存在" : "已加入常用词"
        } catch {
            appState.lastMessage = "常用词保存失败"
        }
    }

    private func ignoreVocabularySuggestion(value: String?, aliases: [String]) {
        guard let value else {
            return
        }

        do {
            if let alias = aliases.first {
                _ = try userVocabularyStore.ignoreSuggestion(value: value, alias: alias)
            }
            removeVocabularySuggestion(value: value)
            appState.lastMessage = "已忽略这条建议"
        } catch {
            removeVocabularySuggestion(value: value)
            appState.lastMessage = "已忽略这条建议"
        }
    }

    private func removeVocabularySuggestion(value: String) {
        let key = value.normalizedSmartTermKey
        appState.userVocabularySuggestions.removeAll {
            $0.value.normalizedSmartTermKey == key
        }
    }

    private func toggleRecording() async {
        switch appState.runtimeState {
        case .recording:
            await finishRecording()
        case .transcribing, .processingAI:
            appState.lastMessage = appState.runtimeState.readyTypeDisplayMessage()
        case .idle, .pasted, .copiedFallback, .error:
            pasteTargetActivator.captureCurrentTarget()
            await beginRecording()
        }
    }

    private func observeRuntimeStateForHUD() {
        appState.$runtimeState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.recordingHUDWindowController?.update()
            }
            .store(in: &stateObservers)
    }

    private func beginRecording() async {
        do {
            idlePrewarmController?.cancel()
            try await voiceInputController?.beginRecording()
            if appState.runtimeState == .recording {
                startEscapeKeyCancelMonitor()
                scheduleAutoFinishRecording()
            }
        } catch {
            escapeKeyCancelMonitor?.stop()
            escapeKeyCancelMonitor = nil
            // VoiceInputController already applies a user-facing app state.
        }
    }

    private func finishRecording() async {
        do {
            autoFinishRecordingTask?.cancel()
            autoFinishRecordingTask = nil
            escapeKeyCancelMonitor?.stop()
            escapeKeyCancelMonitor = nil
            try await voiceInputController?.finishRecording()
        } catch {
            escapeKeyCancelMonitor?.stop()
            escapeKeyCancelMonitor = nil
            // VoiceInputController already applies a user-facing app state.
        }
    }

    private func scheduleAutoFinishRecording() {
        autoFinishRecordingTask?.cancel()
        autoFinishRecordingTask = Task { [weak self, maximumRecordingDuration] in
            try? await Task.sleep(for: maximumRecordingDuration)

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self, self.appState.runtimeState == .recording else {
                    return
                }

                self.appState.lastMessage = RecordingPolicy.autoFinishMessage
                Task { @MainActor in
                    await self.finishRecording()
                }
            }
        }
    }

    private func handlePrewarmStateChange(_ state: LocalSpeechModelState) {
        appState.localSpeechModelState = state
        guard state == .warm, appState.runtimeState == .idle else {
            return
        }

        appState.lastMessage = LocalSpeechModelState.warm.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
    }

    private func showSettingsWindow() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: ReadyTypeMainView(settingsViewModel: makeSettingsViewModel())
                .environmentObject(appState)
        )
        let window = NSWindow(contentViewController: hostingController)
        window.title = "ReadyType"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 900, height: 680))
        window.isReleasedWhenClosed = false
        window.center()
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func prewarmHighAccuracySpeechModelAfterDownload() async -> LocalSpeechModelState {
        guard appState.runtimeState != .recording else {
            return localSpeechModelManager.state()
        }

        guard !ProcessInfo.processInfo.isLowPowerModeEnabled,
              ProcessInfo.processInfo.thermalState != .serious,
              ProcessInfo.processInfo.thermalState != .critical
        else {
            return localSpeechModelManager.state()
        }

        appState.localSpeechModelState = .warming

        do {
            try await highAccuracySpeechEngine.prewarm()
            appState.localSpeechModelState = .warm
            appState.lastMessage = LocalSpeechModelState.warm.readyTypeDisplayMessage(isHighAccuracyEnabled: true)
            return .warm
        } catch {
            let failedState = LocalSpeechModelState.failed(reason: "高精度识别准备失败：\(error.localizedDescription)")
            appState.localSpeechModelState = failedState
            return failedState
        }
    }
}
