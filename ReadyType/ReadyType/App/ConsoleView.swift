import SwiftUI

struct ConsoleView: View {
    @EnvironmentObject private var appState: AppState
    private var preferences: MotionPreferences { .current }
    private var isRecording: Bool { appState.runtimeState == .recording }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                ReadyTypePanel("当前状态", subtitle: "ReadyType 会在你再次\(appState.voiceShortcut.displayName) 后识别、整理并输出到当前输入框；按 Esc 可取消。") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            StatusPill(
                                state: appState.runtimeState,
                                message: appState.runtimeState.readyTypeDisplayMessage(
                                    lastMessage: appState.lastMessage,
                                    shortcut: appState.voiceShortcut
                                )
                            )
                            .animation(MotionTokens.statusAnimation(for: preferences), value: appState.runtimeState)

                            ModeBadge(mode: appState.selectedMode)
                            RecognitionModeBadge(mode: appState.speechRecognitionMode)

                            Spacer()
                        }

                        controlGroup(title: "输出方式") {
                            modePicker
                        }
                        helperText(appState.selectedMode.userDescription)
                        controlGroup(title: "写作场景") {
                            scenarioPicker
                        }
                        .opacity(appState.selectedMode.requiresAI ? 1 : 0.58)
                        helperText(scenarioHelperText)
                        controlGroup(title: "识别状态") {
                            recognitionStatus
                        }
                    }
                }

                recordPanel
                previewPanel
            }
            .padding(26)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ReadyTypeMark(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("ReadyType 控制台")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ReadyTypeTheme.ink)
                Text("\(appState.voiceShortcut.displayName) 开始说话，再次\(appState.voiceShortcut.displayName) 完成并输出；按 Esc 取消。默认不保存完整转写历史。")
                    .font(.callout)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }

            Spacer()
        }
    }

    private var modePicker: some View {
        Picker("输出方式", selection: $appState.selectedMode) {
            ForEach(OutputMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 430)
    }

    private var scenarioPicker: some View {
        Picker("写作场景", selection: $appState.scenarioSelection) {
            ForEach(OutputScenarioSelection.allCases) { selection in
                Text(selection.displayName).tag(selection)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 640)
    }

    private var scenarioHelperText: String {
        if appState.selectedMode.requiresAI {
            return appState.scenarioSelection.userDescription
        }

        return "直接转文字会保留原始识别文本，写作场景只会作为后续切换 AI 输出方式时的格式参考。"
    }

    private var recognitionStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            recognitionStatusRow(
                role: .neutral,
                title: "识别方式",
                detail: recognitionModeDetail
            )

            recognitionStatusRow(
                role: displayLocalSpeechModelState.readyTypeStatusRole(
                    isHighAccuracyEnabled: appState.isHighAccuracyRecognitionEnabled
                ),
                title: "高精度语音包",
                detail: displayLocalSpeechModelState.readyTypeDisplayMessage(
                    isHighAccuracyEnabled: appState.isHighAccuracyRecognitionEnabled
                )
            )

            recognitionStatusRow(
                role: appState.lastSpeechRecognitionRouteDecision?.readyTypeStatusRole ?? .neutral,
                title: "上次实际使用",
                detail: appState.lastSpeechRecognitionRouteDecision?.readyTypeLastRunDisplayMessage ?? "上次识别：尚未开始"
            )
        }
        .padding(10)
        .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
        )
    }

    private var recognitionModeDetail: String {
        switch appState.speechRecognitionMode {
        case .automatic:
            return "自动选择：短句优先快速，长文和专业词会尝试更准确识别"
        case .fastSystem:
            return "极速识别：优先响应速度"
        case .highAccuracyLocal:
            return "高精度识别：优先准确率"
        }
    }

    private var displayLocalSpeechModelState: LocalSpeechModelState {
        if appState.localSpeechModelState == .warm {
            return .warm
        }

        return appState.localSpeechModelState
    }

    private func recognitionStatusRow(role: StatusRole, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            StatusDot(role: role, size: 8)
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(ReadyTypeTheme.ink)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(ReadyTypeTheme.muted)
                .lineLimit(2)
            Spacer()
        }
    }

    private func controlGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.muted)
            content()
        }
    }

    private func helperText(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(ReadyTypeTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var recordPanel: some View {
        ReadyTypePanel("语音输入", subtitle: "开始说话快捷键：\(appState.voiceShortcut.displayName)。也可以在这里点击按钮测试当前流程。") {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    NotificationCenter.default.post(name: .readyTypeToggleRecordingRequested, object: nil)
                } label: {
                    Text(isRecording ? "完成并识别" : "开始说话")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.plain)
                .foregroundStyle(isRecording ? .white : ReadyTypeTheme.accentStrong)
                .background(
                    isRecording ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.fieldStrong,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isRecording ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.stroke, lineWidth: 1)
                )
                .scaleEffect(isRecording && !preferences.reduceMotion ? 0.985 : 1)
                .animation(MotionTokens.statusAnimation(for: preferences), value: isRecording)
                .disabled(appState.runtimeState == .transcribing || appState.runtimeState == .processingAI)
                .opacity(appState.runtimeState == .transcribing || appState.runtimeState == .processingAI ? 0.62 : 1)

                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                    Text(appState.voiceShortcut.trigger.shortDisplayName)
                        .fontDesign(.monospaced)
                    Text("双击开始说话，再次双击完成；Esc 取消")
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
                .font(.footnote)
            }
        }
    }

    private var previewPanel: some View {
        ReadyTypePanel("最近结果", subtitle: "只展示本次运行状态，不建立完整历史记录。") {
            VStack(alignment: .leading, spacing: 12) {
                previewBlock(title: "最近识别文本", text: appState.lastTranscript)
                previewBlock(title: "最终输出", text: appState.lastOutput)

                if let summary = appState.lastProcessingSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("处理方式")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(ReadyTypeTheme.muted)
                        Text(summary)
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                }

                vocabularySuggestionList
            }
        }
    }

    @ViewBuilder
    private var vocabularySuggestionList: some View {
        if !appState.userVocabularySuggestions.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("建议加入常用词")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ReadyTypeTheme.muted)

                ForEach(appState.userVocabularySuggestions) { suggestion in
                    vocabularySuggestionRow(suggestion)
                }
            }
            .transition(.opacity)
        }
    }

    private func vocabularySuggestionRow(_ suggestion: UserVocabularySuggestion) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "text.badge.checkmark")
                .foregroundStyle(ReadyTypeTheme.accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(suggestion.value)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReadyTypeTheme.ink)
                Text(vocabularySuggestionDetail(suggestion))
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)
                    .lineLimit(2)
            }

            Spacer()

            Button("忽略") {
                NotificationCenter.default.post(
                    name: .readyTypeIgnoreVocabularySuggestionRequested,
                    object: nil,
                    userInfo: [
                        "value": suggestion.value,
                        "aliases": suggestion.aliases
                    ]
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(ReadyTypeTheme.muted)

            Button("加入常用词") {
                NotificationCenter.default.post(
                    name: .readyTypeAddVocabularySuggestionRequested,
                    object: nil,
                    userInfo: [
                        "value": suggestion.value,
                        "kind": suggestion.kind.rawValue,
                        "aliases": suggestion.aliases,
                        "scopes": suggestion.scopes.map(\.rawValue),
                        "confidence": suggestion.confidence
                    ]
                )
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(ReadyTypeTheme.accentStrong)
        }
        .padding(12)
        .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ReadyTypeTheme.panelStroke, lineWidth: 1)
        )
    }

    private func vocabularySuggestionDetail(_ suggestion: UserVocabularySuggestion) -> String {
        let aliasText = suggestion.aliases.isEmpty ? "本次识别中出现过" : "可能曾识别为：\(suggestion.aliases.joined(separator: "、"))"
        return "\(vocabularyScopeText(suggestion.scopes)) · \(aliasText) · \(suggestion.reason)"
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

    private func previewBlock(title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.muted)

            if let text, !text.isEmpty {
                Text(text)
                    .font(.callout)
                    .lineLimit(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                    .padding(12)
                    .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(ReadyTypeTheme.panelStroke, lineWidth: 1)
                    )
                    .transition(.opacity)
            } else {
                EmptyPreviewText(text: "暂无内容")
            }
        }
        .animation(MotionTokens.crossfadeAnimation(for: preferences), value: text)
    }
}
