import SwiftUI

struct ReadyTypeMainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: ReadyTypeSection = .home
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var shouldShowPostFirstUsePrompt = false
    @AppStorage("readyTypeAppearance") private var appearanceRawValue = ReadyTypeAppearance.system.rawValue

    init(settingsViewModel: SettingsViewModel = SettingsViewModel()) {
        _settingsViewModel = StateObject(wrappedValue: settingsViewModel)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            VStack(spacing: 0) {
                onboardingArea
                    .padding(.horizontal, 18)
                    .padding(.top, onboardingViewModel.shouldShowOnboarding || shouldShowPostFirstUsePrompt ? 18 : 0)

                detail
                    .environmentObject(appState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(ReadyTypeTheme.pageBackground)
        }
        .background(ReadyTypeTheme.canvas)
        .frame(minWidth: 820, idealWidth: 900, minHeight: 620, idealHeight: 680)
        .preferredColorScheme(appearance.colorScheme)
        .onAppear {
            applyAppearance()
        }
        .onChange(of: appearanceRawValue) { _, _ in
            applyAppearance()
        }
        .onChange(of: appState.runtimeState) { _, newState in
            if onboardingViewModel.shouldShowPostFirstUseModelPrompt(after: newState) {
                withAnimation(MotionTokens.statusAnimation(for: .current)) {
                    shouldShowPostFirstUsePrompt = true
                }
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ReadyTypeMark(size: 38)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ReadyType")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(ReadyTypeTheme.ink)
                    Text("Voice to text")
                        .font(.caption)
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(ReadyTypeSection.allCases) { section in
                    Button {
                        withAnimation(MotionTokens.popoverSelectionAnimation()) {
                            selection = section
                        }
                    } label: {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.callout.weight(selection == section ? .semibold : .regular))
                            .foregroundStyle(selection == section ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                selection == section ? ReadyTypeTheme.accentSoft : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)

            Spacer()

            Picker("外观", selection: $appearanceRawValue) {
                ForEach(ReadyTypeAppearance.allCases) { appearance in
                    Text(appearance.displayName).tag(appearance.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .padding(14)
        }
        .frame(width: 210)
        .background(ReadyTypeTheme.sidebar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(ReadyTypeTheme.strokeSoft)
                .frame(width: 1)
        }
    }

    @ViewBuilder
    private var onboardingArea: some View {
        if onboardingViewModel.shouldShowOnboarding {
            OnboardingView(
                onSkipLocalSpeechModel: {
                    onboardingViewModel.skipLocalSpeechModel()
                    syncAppStateRecognitionSettings()
                },
                onEnableLocalSpeechModel: {
                    onboardingViewModel.enableLocalSpeechModel()
                    selection = .speechRecognition
                    syncAppStateRecognitionSettings()
                },
                onDismiss: {
                    onboardingViewModel.dismissOnboarding()
                }
            )
        } else if shouldShowPostFirstUsePrompt {
            PostFirstUseModelPromptView(
                onEnableLocalSpeechModel: {
                    onboardingViewModel.enableLocalSpeechModel()
                    onboardingViewModel.markPostFirstUseModelPromptShown()
                    selection = .speechRecognition
                    shouldShowPostFirstUsePrompt = false
                    syncAppStateRecognitionSettings()
                },
                onDismiss: {
                    onboardingViewModel.markPostFirstUseModelPromptShown()
                    shouldShowPostFirstUsePrompt = false
                }
            )
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .home:
            ConsoleView()
        case .vocabulary:
            SettingsPane(viewModel: settingsViewModel, section: .vocabulary)
        case .languageOutput:
            SettingsPane(viewModel: settingsViewModel, section: .languageOutput)
        case .shortcuts:
            SettingsPane(viewModel: settingsViewModel, section: .shortcuts)
        case .speechRecognition:
            SettingsPane(viewModel: settingsViewModel, section: .speechRecognition)
        case .permissions:
            PermissionsPane()
        case .about:
            AboutPane()
        }
    }

    private func syncAppStateRecognitionSettings() {
        let settings = SettingsStore().load()
        appState.speechRecognitionMode = settings.speechRecognitionMode
        appState.isHighAccuracyRecognitionEnabled = settings.isHighAccuracyRecognitionEnabled
        appState.voiceShortcut = settings.voiceShortcut
        if settings.isHighAccuracyRecognitionEnabled {
            appState.localSpeechModelState = LocalSpeechModelReadiness.displayState(
                diskState: LocalSpeechModelManager().state(),
                runtimeState: appState.localSpeechModelState
            )
        } else {
            appState.localSpeechModelState = .notInstalled
        }
    }

    private var appearance: ReadyTypeAppearance {
        ReadyTypeAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private func applyAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

private enum ReadyTypeSection: String, CaseIterable, Identifiable {
    case home
    case vocabulary
    case languageOutput
    case shortcuts
    case speechRecognition
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "首页"
        case .vocabulary: return "常用词"
        case .languageOutput: return "语言与输出"
        case .shortcuts: return "快捷键"
        case .speechRecognition: return "语音识别"
        case .permissions:
            return "权限与隐私"
        case .about:
            return "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .vocabulary: return "text.book.closed"
        case .languageOutput: return "character.bubble"
        case .shortcuts: return "keyboard"
        case .speechRecognition: return "waveform"
        case .permissions:
            return "checkmark.shield"
        case .about:
            return "info.circle"
        }
    }
}
