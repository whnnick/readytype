import SwiftUI

struct ReadyTypeMainView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selection: ReadyTypeSection = .home
    @State private var settingsSelection: ReadyTypeSettingsSection = .general
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var settingsViewModel: SettingsViewModel
    @State private var shouldShowPostFirstUsePrompt = false
    @State private var systemColorScheme = ReadyTypeAppearance.currentSystemColorScheme
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
        .environment(\.colorScheme, effectiveColorScheme)
        .animation(.easeInOut(duration: 0.22), value: effectiveColorScheme)
        .onAppear {
            applyAppearance()
        }
        .onChange(of: appearanceRawValue) { _, _ in
            applyAppearance()
        }
        .onReceive(
            DistributedNotificationCenter.default().publisher(
                for: Notification.Name("AppleInterfaceThemeChangedNotification")
            )
        ) { _ in
            systemColorScheme = ReadyTypeAppearance.currentSystemColorScheme
            if appearance == .system {
                applyAppearance()
            }
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(ReadyTypeSection.primarySections) { section in
                    sidebarButton(for: section)
                }
            }
            .padding(.horizontal, 14)

            Spacer()

            sidebarButton(for: .settings)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
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
                    openSettings(.speechRecognition)
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
                    openSettings(.speechRecognition)
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
        case .dashboard:
            DashboardView()
        case .home:
            ConsoleView()
        case .vocabulary:
            SettingsPane(viewModel: settingsViewModel, section: .vocabulary)
        case .settings:
            SettingsWorkspaceView(selection: $settingsSelection, viewModel: settingsViewModel)
        }
    }

    private func sidebarButton(for section: ReadyTypeSection) -> some View {
        Button {
            withAnimation(MotionTokens.popoverSelectionAnimation()) {
                selection = section
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 20, alignment: .center)

                Text(section.title)
                    .font(.callout.weight(selection == section ? .semibold : .regular))
            }
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

    private func openSettings(_ destination: ReadyTypeSettingsSection) {
        settingsSelection = destination
        selection = .settings
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

    private var effectiveColorScheme: ColorScheme {
        appearance.colorScheme ?? systemColorScheme
    }

    private func applyAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
            systemColorScheme = ReadyTypeAppearance.currentSystemColorScheme
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

enum ReadyTypeSection: String, CaseIterable, Identifiable {
    case home
    case dashboard
    case vocabulary
    case settings

    static let primarySections: [ReadyTypeSection] = [.home, .dashboard, .vocabulary]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "使用概览"
        case .home: return "首页"
        case .vocabulary: return "常用词"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .home: return "house"
        case .vocabulary: return "text.book.closed"
        case .settings: return "gearshape"
        }
    }
}

enum ReadyTypeSettingsSection: String, CaseIterable, Identifiable {
    case general
    case speechRecognition
    case shortcuts
    case permissions
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "通用"
        case .speechRecognition: "语音识别"
        case .shortcuts: "快捷键"
        case .permissions: "权限与隐私"
        case .about: "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .speechRecognition: "waveform"
        case .shortcuts: "keyboard"
        case .permissions: "checkmark.shield"
        case .about: "info.circle"
        }
    }
}

private struct SettingsWorkspaceView: View {
    @Binding var selection: ReadyTypeSettingsSection
    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ReadyTypeSettingsSection.allCases) { section in
                        Button {
                            withAnimation(MotionTokens.popoverSelectionAnimation()) {
                                selection = section
                            }
                        } label: {
                            Label(section.title, systemImage: section.systemImage)
                                .font(.callout.weight(selection == section ? .semibold : .regular))
                                .foregroundStyle(selection == section ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.ink)
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
                .padding(.horizontal, 26)
                .padding(.vertical, 12)
            }
            .background(ReadyTypeTheme.pageBackground)

            Divider()

            Group {
                switch selection {
                case .general:
                    SettingsPane(viewModel: viewModel, section: .general)
                case .speechRecognition:
                    SettingsPane(viewModel: viewModel, section: .speechRecognition)
                case .shortcuts:
                    SettingsPane(viewModel: viewModel, section: .shortcuts)
                case .permissions:
                    PermissionsPane(viewModel: viewModel)
                case .about:
                    AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
