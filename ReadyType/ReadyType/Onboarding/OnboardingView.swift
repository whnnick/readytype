import SwiftUI

struct OnboardingView: View {
    let onSkipLocalSpeechModel: () -> Void
    let onEnableLocalSpeechModel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ReadyTypePanel("开始使用 ReadyType", subtitle: "先完成必要设置；高精度语音包可稍后再安装。") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    onboardingItem(systemImage: "key.fill", title: "填写 DeepSeek API Key", detail: "整理成文、翻译英文和写给 AI 会使用它；直接转文字不调用。")
                    onboardingItem(systemImage: "checkmark.shield.fill", title: "允许系统权限", detail: "麦克风、语音识别和辅助功能用于接收语音、转成文字和自动粘贴。")
                    onboardingItem(systemImage: "waveform", title: "选择识别方式", detail: "默认自动选择；短句保持快速，长文、邮件和专业词可使用更准确的识别。")
                }

                Divider()
                    .overlay(ReadyTypeTheme.strokeSoft)

                HStack(spacing: 10) {
                    Button("先用快速识别") {
                        onSkipLocalSpeechModel()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("启用更准确的识别") {
                        onEnableLocalSpeechModel()
                    }

                    Button("稍后设置") {
                        onDismiss()
                    }

                    Spacer()

                    Text("高精度语音包约 626 MiB，可随时删除。")
                        .font(.footnote)
                        .foregroundStyle(ReadyTypeTheme.muted)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func onboardingItem(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ReadyTypeTheme.accentStrong)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReadyTypeTheme.ink)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PostFirstUseModelPromptView: View {
    let onEnableLocalSpeechModel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusDot(role: .warning)

            VStack(alignment: .leading, spacing: 3) {
                Text("长文、邮件和专业词想更准，可以安装高精度语音包")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(ReadyTypeTheme.ink)
                Text("安装后会在后台准备；短句仍优先快速响应，复杂内容会更受益。")
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }

            Spacer()

            Button("启用并下载") {
                onEnableLocalSpeechModel()
            }

            Button("不再提示") {
                onDismiss()
            }
        }
        .padding(14)
        .background(ReadyTypeTheme.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(ReadyTypeTheme.panelStroke, lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
