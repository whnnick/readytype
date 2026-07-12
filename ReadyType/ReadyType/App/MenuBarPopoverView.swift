import SwiftUI

struct MenuBarPopoverView: View {
    @ObservedObject var appState: AppState
    let openConsole: () -> Void
    let quit: () -> Void

    private var preferences: MotionPreferences { .current }
    @AppStorage("readyTypeAppearance") private var appearanceRawValue = ReadyTypeAppearance.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            modes
            controls
        }
        .padding(14)
        .frame(
            width: MenuBarPopoverLayout.width,
            height: MenuBarPopoverLayout.height,
            alignment: .top
        )
        .background(ReadyTypeTheme.canvas)
        .preferredColorScheme(appearance.colorScheme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                ReadyTypeMark(size: 28)
                StatusDot(role: appState.runtimeState.readyTypeStatusRole, size: 8)
                Text(appState.runtimeState.readyTypeDisplayMessage(
                    lastMessage: appState.lastMessage,
                    shortcut: appState.voiceShortcut
                ))
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(ReadyTypeTheme.ink)
                Spacer()
                Text(appState.voiceShortcut.trigger.shortDisplayName)
                    .font(.caption.monospaced())
                    .foregroundStyle(ReadyTypeTheme.muted)
            }

            HStack(spacing: 8) {
                ModeBadge(mode: appState.selectedMode)
                RecognitionModeBadge(mode: appState.speechRecognitionMode)
                if let summary = appState.scenarioSelection.compactSummary(for: appState.selectedMode) {
                    Text(summary)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
            }

            HStack(spacing: 7) {
                StatusDot(
                    role: appState.localSpeechModelState.readyTypeStatusRole(
                        isHighAccuracyEnabled: appState.isHighAccuracyRecognitionEnabled
                    ),
                    size: 7
                )
                Text(appState.localSpeechModelState.readyTypeDisplayMessage(isHighAccuracyEnabled: appState.isHighAccuracyRecognitionEnabled))
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }

            HStack(spacing: 7) {
                StatusDot(
                    role: appState.lastSpeechRecognitionRouteDecision?.readyTypeStatusRole ?? .neutral,
                    size: 7
                )
                Text(appState.lastSpeechRecognitionRouteDecision?.readyTypeLastRunDisplayMessage ?? "上次识别：尚未开始")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }
        }
    }

    private var appearance: ReadyTypeAppearance {
        ReadyTypeAppearance(rawValue: appearanceRawValue) ?? .system
    }

    private var modes: some View {
        VStack(spacing: 6) {
            ForEach(OutputMode.allCases) { mode in
                Button {
                    withAnimation(MotionTokens.popoverSelectionAnimation(for: preferences)) {
                        appState.selectedMode = mode
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: appState.selectedMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(appState.selectedMode == mode ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.muted)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(mode.displayName)
                                .font(.callout.weight(.medium))
                                .foregroundStyle(ReadyTypeTheme.ink)
                            Text(mode.userDescription)
                                .font(.caption)
                                .foregroundStyle(ReadyTypeTheme.muted)
                                .lineLimit(2)
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        appState.selectedMode == mode ? ReadyTypeTheme.accentSoft : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(appState.selectedMode == mode ? ReadyTypeTheme.strokeSoft : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controls: some View {
        HStack {
            Button("打开控制台") {
                openConsole()
            }
            .buttonStyle(.borderedProminent)
            .tint(ReadyTypeTheme.accentStrong)

            Spacer()

            Button("退出") {
                quit()
            }
            .buttonStyle(.bordered)
        }
    }
}
