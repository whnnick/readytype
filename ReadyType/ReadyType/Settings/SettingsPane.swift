import SwiftUI

struct SettingsPane: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: SettingsViewModel
    @State private var errorMessage: String?

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                ReadyTypePanel("识别方式", subtitle: "默认保持快速响应，遇到长文、邮件和专业词时自动提高准确率。") {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        GridRow {
                            Text("当前识别方式")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Picker("当前识别方式", selection: $viewModel.speechRecognitionMode) {
                                ForEach(SpeechRecognitionMode.allCases, id: \.self) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 320)
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(viewModel.speechRecognitionMode.userDescription)
                        Text("语音识别本身不需要额外付费接口；只有整理、翻译和写给 AI 会使用 DeepSeek 处理当前文本。")
                        Text("安装高精度语音包后，ReadyType 会在后台准备更准确的识别；准备期间仍可继续说话和输入。")
                    }
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)

                    Toggle("启用更准确的本机识别", isOn: $viewModel.isHighAccuracyRecognitionEnabled)
                        .toggleStyle(.checkbox)

                    Toggle("空闲时提前准备，降低第一次等待", isOn: $viewModel.isIdlePrewarmEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!viewModel.isHighAccuracyRecognitionEnabled)
                        .opacity(viewModel.isHighAccuracyRecognitionEnabled ? 1 : 0.55)

                    HStack(spacing: 10) {
                        StatusDot(
                            role: localSpeechModelState.readyTypeStatusRole(
                                isHighAccuracyEnabled: viewModel.isHighAccuracyRecognitionEnabled
                            )
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(localSpeechModelState.readyTypeDisplayMessage(isHighAccuracyEnabled: viewModel.isHighAccuracyRecognitionEnabled))
                                .font(.callout.weight(.medium))
                                .foregroundStyle(ReadyTypeTheme.ink)
                            Text(highAccuracyDetailText)
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        StatusDot(role: viewModel.localSpeechModelUpdateStatus.readyTypeStatusRole)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("更新状态")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(ReadyTypeTheme.ink)
                            Text(viewModel.localSpeechModelUpdateStatus.readyTypeDisplayMessage)
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                        }
                        Spacer()
                        Button(speechModelUpdateButtonTitle) {
                            checkHighAccuracySpeechModelUpdate()
                        }
                        .disabled(!canCheckSpeechModelUpdate)
                    }
                    .padding(12)
                    .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
                    )

                    HStack(spacing: 10) {
                        Button(downloadSpeechModelButtonTitle) {
                            downloadHighAccuracySpeechModel()
                        }
                        .disabled(!canDownloadSpeechModel)

                        Button("删除语音包") {
                            deleteHighAccuracySpeechModel()
                        }
                        .disabled(!canDeleteSpeechModel)

                        Spacer()

                        Text("高精度语音包约 626 MiB；下载和准备期间仍可继续使用快速识别。")
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.muted)
                    }

                    Text("高精度语音包保存在 \(LocalSpeechModelManager.defaultModelsDirectoryPath())。可在这里删除；以后需要更新时可重新下载。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)
                }

                ReadyTypePanel("常用词", subtitle: "添加人名、产品名、项目名、公司名和常用短语，帮助 ReadyType 更稳定地保留原词。") {
                    Toggle(
                        "完成输入后提示可加入的常用词",
                        isOn: Binding(
                            get: { viewModel.isVocabularyLearningSuggestionsEnabled },
                            set: { viewModel.setVocabularyLearningSuggestionsEnabled($0) }
                        )
                    )
                        .toggleStyle(.checkbox)

                    Text("开启后，ReadyType 会在最近结果里提示是否加入可能的固定写法；只有点击“加入常用词”才会保存。关闭后，已保存常用词仍会继续生效。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        GridRow {
                            Text("类型")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Picker("类型", selection: $viewModel.selectedVocabularyKind) {
                                ForEach(UserVocabularyKind.allCases) { kind in
                                    Text(kind.displayName).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 220)
                        }

                        GridRow {
                            Text("新增")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            HStack(spacing: 10) {
                                TextField("例如：张三、ReadyType、GitHub Actions", text: $viewModel.newVocabularyText)
                                    .textFieldStyle(.roundedBorder)
                                Button("添加") {
                                    addUserVocabularyEntry()
                                }
                                .disabled(viewModel.newVocabularyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("批量导入")
                            .font(.callout.weight(.medium))
                        TextEditor(text: $viewModel.importVocabularyText)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 76)
                            .padding(8)
                            .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
                            )
                        HStack {
                            Text("一行一个词。只保存你明确添加的内容。")
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Spacer()
                            Button("导入") {
                                importUserVocabularyEntries()
                            }
                            .disabled(viewModel.importVocabularyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if viewModel.userVocabularyEntries.isEmpty {
                        Text("还没有常用词。")
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.muted)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.userVocabularyEntries) { entry in
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 8) {
                                            Text(entry.value)
                                                .font(.callout.weight(.medium))
                                                .foregroundStyle(ReadyTypeTheme.ink)
                                            Text(entry.kind.displayName)
                                                .font(.footnote)
                                                .foregroundStyle(ReadyTypeTheme.muted)
                                        }
                                        Text(vocabularyEntryDetail(entry))
                                            .font(.footnote)
                                            .foregroundStyle(ReadyTypeTheme.muted)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Button("删除") {
                                        deleteUserVocabularyEntry(id: entry.id)
                                    }
                                }
                                .padding(10)
                                .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
                                )
                            }
                        }
                    }
                }

                ReadyTypePanel("DeepSeek 连接", subtitle: "只用于整理、翻译和写给 AI；直接转文字不会使用。") {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        GridRow {
                            Text("默认输出方式")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Picker("默认输出方式", selection: $viewModel.defaultMode) {
                                ForEach(OutputMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 320)
                        }

                        GridRow {
                            Text("服务地址")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            TextField("https://api.deepseek.com", text: $viewModel.baseURLText)
                                .textFieldStyle(.roundedBorder)
                        }

                        GridRow {
                            Text("模型名称")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            TextField("deepseek-chat", text: $viewModel.model)
                                .textFieldStyle(.roundedBorder)
                        }

                        GridRow {
                            Text("DeepSeek 密钥")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            SecureField(viewModel.hasSavedAPIKey ? "已保存在钥匙串，留空则保持不变" : "输入 DeepSeek 密钥", text: $viewModel.apiKeyText)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Toggle("自动粘贴到当前输入框；失败时复制到剪贴板", isOn: $viewModel.pasteAutomatically)
                        .toggleStyle(.checkbox)

                    HStack {
                        Button("保存设置") {
                            save()
                        }
                        .keyboardShortcut(.defaultAction)

                        Button("清除密钥") {
                            clearAPIKey()
                        }
                        .disabled(!viewModel.hasSavedAPIKey && viewModel.apiKeyText.isEmpty)

                        Button(viewModel.isTestingAPIConnection ? "测试中..." : "测试连接") {
                            testAPIConnection()
                        }
                        .disabled(viewModel.isTestingAPIConnection)

                        Spacer()

                        if let statusMessage = viewModel.statusMessage {
                            Text(statusMessage)
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.danger)
                    }

                    apiConnectionStatus
                }

                ReadyTypePanel("开始说话快捷键", subtitle: "选择一个按两次就能开始或完成输入的按键。") {
                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        GridRow {
                            Text("当前快捷键")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Picker("当前快捷键", selection: $viewModel.voiceShortcut.trigger) {
                                ForEach(VoiceShortcutTrigger.allCases) { trigger in
                                    Text(trigger.displayName).tag(trigger)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 260)
                        }
                    }

                    HStack(spacing: 10) {
                        Label("保存后立即生效；Esc 取消保持不变。", systemImage: "keyboard")
                            .foregroundStyle(ReadyTypeTheme.muted)
                        Spacer()
                        Button("恢复默认") {
                            viewModel.voiceShortcut = .default
                        }
                        .disabled(viewModel.voiceShortcut == .default)
                    }
                    .font(.footnote)
                }

                ReadyTypePanel("输出体验", subtitle: "开始、取消和输出都保持低打扰。") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(viewModel.voiceShortcut.displayName) 开始说话，再次\(viewModel.voiceShortcut.displayName) 完成并输出；Esc 可取消。", systemImage: "keyboard")
                        Label("菜单栏浮窗可快速切换直接转文字、整理成文、翻译成英文、写给 AI。", systemImage: "menubar.rectangle")
                        Label("语音输入浮层遵循系统“减少动态效果”设置。", systemImage: "accessibility")
                    }
                    .font(.callout)
                }
            }
            .padding(26)
        }
        .onReceive(viewModel.$localSpeechModelState) { state in
            appState.localSpeechModelState = LocalSpeechModelReadiness.displayState(
                diskState: state,
                runtimeState: appState.localSpeechModelState
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("设置")
                .font(.title2.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.ink)
            Text("识别方式、DeepSeek、输出方式与语音包状态。")
                .foregroundStyle(ReadyTypeTheme.muted)
        }
    }

    private var localSpeechModelState: LocalSpeechModelState {
        LocalSpeechModelReadiness.displayState(
            diskState: viewModel.localSpeechModelState,
            runtimeState: appState.localSpeechModelState
        )
    }

    private var highAccuracyDetailText: String {
        guard viewModel.isHighAccuracyRecognitionEnabled else {
            return "关闭时 ReadyType 只使用快速识别，开始说话不会等待高精度语音包。"
        }

        if viewModel.isIdlePrewarmEnabled {
            return "启用后，ReadyType 会尽量在你不使用语音输入时提前准备更准确的识别。"
        }

        return "关闭提前准备后，第一次使用更准确的识别可能需要短暂等待。"
    }

    private func vocabularyEntryDetail(_ entry: UserVocabularyEntry) -> String {
        let aliasText = entry.aliases.isEmpty ? "暂无识别别名" : "可能识别成：\(entry.aliases.joined(separator: "、"))"
        return "\(vocabularyScopeText(entry.scopes)) · \(aliasText)"
    }

    private func vocabularyScopeText(_ scopes: [UserVocabularyScope]) -> String {
        if scopes.contains(.all) {
            return "所有场景"
        }

        return scopes.map { scope in
            switch scope {
            case .all:
                return "所有场景"
            case .chat:
                return "聊天"
            case .email:
                return "邮件"
            case .document:
                return "文档"
            case .technical:
                return "技术内容"
            case .aiTool:
                return "AI 工具"
            }
        }
        .joined(separator: "、")
    }

    private var canDownloadSpeechModel: Bool {
        guard viewModel.isHighAccuracyRecognitionEnabled,
              !viewModel.isDownloadingSpeechModel
        else {
            return false
        }

        switch localSpeechModelState {
        case .notInstalled, .failed:
            return true
        case .downloading, .downloadedCold, .warming, .warm:
            return false
        }
    }

    private var canDeleteSpeechModel: Bool {
        guard !viewModel.isDownloadingSpeechModel else {
            return false
        }

        switch localSpeechModelState {
        case .downloadedCold, .warming, .warm, .failed:
            return true
        case .notInstalled, .downloading:
            return false
        }
    }

    private var canCheckSpeechModelUpdate: Bool {
        guard viewModel.isHighAccuracyRecognitionEnabled,
              !viewModel.isDownloadingSpeechModel,
              !viewModel.isCheckingSpeechModelUpdate
        else {
            return false
        }

        switch localSpeechModelState {
        case .downloadedCold, .warm:
            return true
        case .notInstalled, .downloading, .warming, .failed:
            return false
        }
    }

    private var downloadSpeechModelButtonTitle: String {
        if viewModel.isDownloadingSpeechModel {
            return "下载中..."
        }

        switch localSpeechModelState {
        case .failed:
            return "重试下载"
        default:
            return "下载语音包"
        }
    }

    private var speechModelUpdateButtonTitle: String {
        viewModel.isCheckingSpeechModelUpdate ? "检查中..." : "检查更新"
    }

    private var apiConnectionStatus: some View {
        HStack(spacing: 10) {
            StatusDot(role: viewModel.apiConnectionTestState.status.role)
            VStack(alignment: .leading, spacing: 3) {
                Text(viewModel.apiConnectionTestState.status.title)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(ReadyTypeTheme.ink)
                Text(viewModel.apiConnectionTestState.displayDetail)
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }
            Spacer()
        }
        .padding(12)
        .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
        )
    }

    private func save() {
        do {
            try viewModel.save()
            appState.selectedMode = viewModel.defaultMode
            appState.speechRecognitionMode = viewModel.speechRecognitionMode
            appState.isHighAccuracyRecognitionEnabled = viewModel.isHighAccuracyRecognitionEnabled
            appState.localSpeechModelState = localSpeechModelState
            appState.voiceShortcut = viewModel.voiceShortcut
            errorMessage = nil
        } catch let error as ReadyTypeError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func downloadHighAccuracySpeechModel() {
        errorMessage = nil
        Task {
            await viewModel.downloadHighAccuracySpeechModel()
            appState.localSpeechModelState = localSpeechModelState
        }
    }

    private func checkHighAccuracySpeechModelUpdate() {
        errorMessage = nil
        Task {
            await viewModel.checkHighAccuracySpeechModelUpdate()
        }
    }

    private func deleteHighAccuracySpeechModel() {
        do {
            try viewModel.deleteHighAccuracySpeechModel()
            appState.localSpeechModelState = viewModel.localSpeechModelState
            errorMessage = nil
        } catch let error as ReadyTypeError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func addUserVocabularyEntry() {
        do {
            try viewModel.addUserVocabularyEntry()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importUserVocabularyEntries() {
        do {
            try viewModel.importUserVocabularyEntries()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteUserVocabularyEntry(id: UUID) {
        do {
            try viewModel.deleteUserVocabularyEntry(id: id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func clearAPIKey() {
        do {
            try viewModel.clearAPIKey()
            errorMessage = nil
        } catch let error as ReadyTypeError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func testAPIConnection() {
        errorMessage = nil
        Task {
            await viewModel.testAPIConnection()
        }
    }
}
