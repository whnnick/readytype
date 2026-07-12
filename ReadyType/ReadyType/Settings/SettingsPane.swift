import SwiftUI

enum SettingsPaneSection: Equatable {
    case vocabulary
    case languageOutput
    case shortcuts
    case speechRecognition

    var title: String {
        switch self {
        case .vocabulary: "常用词"
        case .languageOutput: "语言与输出"
        case .shortcuts: "快捷键"
        case .speechRecognition: "语音识别"
        }
    }

    var subtitle: String {
        switch self {
        case .vocabulary: "添加容易识别错的人名、品牌和专业词，让下次输入更准确。"
        case .languageOutput: "选择输出方式，并管理 DeepSeek 连接。"
        case .shortcuts: "设置开始、完成和取消语音输入的操作。"
        case .speechRecognition: "管理识别方式和高精度语音包。"
        }
    }
}

struct SettingsPane: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: SettingsViewModel
    @State private var errorMessage: String?
    @State private var isShowingAdvancedConnection = false
    @State private var vocabularyEntryPendingSplit: UserVocabularyEntry?
    private let section: SettingsPaneSection

    init(viewModel: SettingsViewModel, section: SettingsPaneSection = .speechRecognition) {
        self.viewModel = viewModel
        self.section = section
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if section == .speechRecognition {
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

                    Text("空格属于词语本身，不会自动分隔。添加多个词时，请使用下方的“一次添加多个”，并用换行、逗号、顿号或分号分隔。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)

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

                }

                if section == .vocabulary {
                ReadyTypePanel("常用词有什么用？", subtitle: "提前告诉 ReadyType 正确写法，语音输入时就更不容易写错。") {
                    Toggle(
                        "发现可能写错的专有词时提醒我",
                        isOn: Binding(
                            get: { viewModel.isVocabularyLearningSuggestionsEnabled },
                            set: { viewModel.setVocabularyLearningSuggestionsEnabled($0) }
                        )
                    )
                        .toggleStyle(.checkbox)

                    Text("例如你说“ReadyType”，却被识别成“Reddit Tab”，输入完成后会显示修正建议。只有你点击“加入常用词”后才会保存。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                        GridRow {
                            Text("分类（可选）")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Picker("分类", selection: $viewModel.selectedVocabularyKind) {
                                ForEach(UserVocabularyKind.allCases) { kind in
                                    Text(kind.displayName).tag(kind)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 220)
                        }

                        GridRow {
                            Text("添加一个")
                                .foregroundStyle(ReadyTypeTheme.muted)
                            HStack(spacing: 10) {
                                TextField("例如：ReadyType", text: $viewModel.newVocabularyText)
                                    .textFieldStyle(.roundedBorder)
                                Button("添加") {
                                    addUserVocabularyEntry()
                                }
                                .disabled(viewModel.newVocabularyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("一次添加多个")
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
                            Text("用换行、逗号、顿号或分号分隔；词语内部可以有空格。添加后会分别显示。")
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                            Spacer()
                            Button("全部添加") {
                                importUserVocabularyEntries()
                            }
                            .disabled(viewModel.importVocabularyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if let statusMessage = viewModel.statusMessage {
                        Text(statusMessage)
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.muted)
                    }

                    if viewModel.userVocabularyEntries.isEmpty {
                        Text("还没有添加常用词。可以先加入经常被识别错的人名或产品名。")
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
                                        if let detail = vocabularyEntryDetail(entry) {
                                            Text(detail)
                                                .font(.footnote)
                                                .foregroundStyle(ReadyTypeTheme.muted)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                    if entry.value.split(whereSeparator: { $0.isWhitespace }).count > 1 {
                                        Button("拆分") {
                                            vocabularyEntryPendingSplit = entry
                                        }
                                    }
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

                }

                if section == .languageOutput {
                ReadyTypePanel("默认输出", subtitle: "每次语音输入默认得到什么结果；也可以从菜单栏临时切换。") {
                    Picker("默认输出", selection: $viewModel.defaultMode) {
                        ForEach(OutputMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(viewModel.defaultMode.userDescription)
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("中文文字")
                                .font(.callout.weight(.medium))
                            Text("统一语音识别和 AI 整理后的中文写法。")
                                .font(.footnote)
                                .foregroundStyle(ReadyTypeTheme.muted)
                        }
                        Spacer()
                        Picker("中文文字", selection: $viewModel.chineseTextStyle) {
                            ForEach(ChineseTextStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }

                ReadyTypePanel("AI 功能", subtitle: "整理成文、翻译成英文和写给 AI 时使用 DeepSeek；直接转文字不使用。") {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("DeepSeek 密钥")
                            .font(.callout.weight(.medium))
                        SecureField(viewModel.hasSavedAPIKey ? "密钥已安全保存；留空不会更改" : "输入你的 DeepSeek 密钥", text: $viewModel.apiKeyText)
                            .textFieldStyle(.roundedBorder)
                        Text("密钥只保存在这台 Mac 的系统钥匙串中。")
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.muted)
                    }

                    DisclosureGroup("高级连接设置", isExpanded: $isShowingAdvancedConnection) {
                        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 12) {
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
                        }
                        .padding(.top, 8)
                    }

                    HStack {
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

                ReadyTypePanel("输入到当前 App", subtitle: "语音处理完成后，ReadyType 如何交付结果。") {
                    Toggle("自动输入到当前光标位置", isOn: $viewModel.pasteAutomatically)
                        .toggleStyle(.checkbox)
                    Text("如果当前 App 不允许自动输入，结果会复制到剪贴板，不会丢失。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)

                    HStack {
                        Spacer()
                        Button("保存语言与输出设置") {
                            save()
                        }
                        .keyboardShortcut(.defaultAction)
                    }
                }

                }

                if section == .shortcuts {
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

                }

                if section == .shortcuts {
                ReadyTypePanel("输出体验", subtitle: "开始、取消和输出都保持低打扰。") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(viewModel.voiceShortcut.displayName) 开始说话，再次\(viewModel.voiceShortcut.displayName) 完成并输出；Esc 可取消。", systemImage: "keyboard")
                        Label("菜单栏浮窗可快速切换直接转文字、整理成文、翻译成英文、写给 AI。", systemImage: "menubar.rectangle")
                        Label("语音输入浮层遵循系统“减少动态效果”设置。", systemImage: "accessibility")
                    }
                    .font(.callout)
                }
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
        .confirmationDialog(
            "按空格拆分这条常用词？",
            isPresented: Binding(
                get: { vocabularyEntryPendingSplit != nil },
                set: { if !$0 { vocabularyEntryPendingSplit = nil } }
            ),
            presenting: vocabularyEntryPendingSplit
        ) { entry in
            Button("拆分为独立常用词") {
                splitUserVocabularyEntry(id: entry.id)
            }
            Button("保留为一个词组", role: .cancel) {}
        } message: { entry in
            Text("“\(entry.value)”会按空格拆分。适用于误把多个词输在一行的情况；GitHub Actions 等固定词组应保留。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(section.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.ink)
            Text(section.subtitle)
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

    private func vocabularyEntryDetail(_ entry: UserVocabularyEntry) -> String? {
        var details: [String] = []
        if !entry.scopes.contains(.all) {
            details.append("优先用于：\(vocabularyScopeText(entry.scopes))")
        }
        if !entry.aliases.isEmpty {
            details.append("常见误识别：\(entry.aliases.joined(separator: "、"))")
        }

        return details.isEmpty ? nil : details.joined(separator: " · ")
    }

    private func vocabularyScopeText(_ scopes: [UserVocabularyScope]) -> String {
        if scopes.contains(.all) {
            return "所有场景"
        }

        return scopes.map(\.displayName).joined(separator: "、")
    }

    private var canDownloadSpeechModel: Bool {
        guard viewModel.isHighAccuracyRecognitionEnabled,
              !viewModel.isDownloadingSpeechModel
        else {
            return false
        }

        if case .updateAvailable = viewModel.localSpeechModelUpdateStatus {
            return true
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

        if case .updateAvailable = viewModel.localSpeechModelUpdateStatus {
            return "更新语音包"
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

    private func splitUserVocabularyEntry(id: UUID) {
        do {
            try viewModel.splitUserVocabularyEntry(id: id)
            vocabularyEntryPendingSplit = nil
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
