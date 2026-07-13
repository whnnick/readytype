import SwiftUI

struct PermissionsPane: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var viewModel: SettingsViewModel
    @State private var permissionSnapshot = PermissionService().snapshot()

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                ReadyTypePanel("授权状态", subtitle: "ReadyType 需要最少权限完成语音输入、识别和自动粘贴。") {
                    VStack(spacing: 10) {
                        PermissionRow(
                            title: "麦克风",
                            description: "\(appState.voiceShortcut.displayName) 后接收你的语音，按 Esc 可取消。",
                            status: permissionSnapshot.microphone,
                            systemImage: "mic"
                        )
                        PermissionRow(
                            title: "语音识别",
                            description: "用于快速把语音转成文字；高精度识别会使用你下载的语音包。",
                            status: permissionSnapshot.speechRecognition,
                            systemImage: "waveform"
                        )
                        PermissionRow(
                            title: "辅助功能",
                            description: "自动粘贴到当前输入框；未授权时复制到剪贴板。",
                            status: permissionSnapshot.accessibility,
                            systemImage: "cursorarrow.motionlines"
                        )
                    }

                    HStack {
                        Button("请求麦克风与语音识别") {
                            Task { @MainActor in
                                permissionSnapshot = await PermissionService().requestCorePermissions()
                            }
                        }

                        Button("打开辅助功能授权") {
                            _ = PermissionService.promptForAccessibilityPermission()
                            permissionSnapshot = PermissionService().snapshot()
                            openAccessibilitySettings()
                        }

                        Button("刷新状态") {
                            permissionSnapshot = PermissionService().snapshot()
                        }
                    }
                }

                ReadyTypePanel("隐私说明", subtitle: "ReadyType 的正式版默认采用低留存策略。") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("不保存完整转写历史；控制台只显示最近一次识别和输出结果。", systemImage: "clock.badge.checkmark")
                        Label("DeepSeek 密钥存入 macOS 钥匙串，不写入项目文件。", systemImage: "key")
                        Label("直接转文字不调用 DeepSeek；整理成文、翻译成英文与写给 AI 会发送当前转写文本。", systemImage: "lock.shield")
                        Label("高精度识别只使用本地语音包；未安装、未就绪或低电量时会回退极速识别。", systemImage: "cpu")
                        Divider()
                        Toggle(
                            "帮助改进 ReadyType",
                            isOn: Binding(
                                get: { viewModel.isAnonymousAnalyticsEnabled },
                                set: { viewModel.setAnonymousAnalyticsEnabled($0) }
                            )
                        )
                        .toggleStyle(.checkbox)
                        Text("只发送匿名的功能使用、性能分桶、固定错误码，以及用于兼容性分析的 App 与系统信息；不会发送语音、文字内容、窗口标题、常用词、剪贴板或 DeepSeek 密钥。公开源码构建默认不发送统计。")
                            .font(.footnote)
                            .foregroundStyle(ReadyTypeTheme.muted)
                    }
                    .font(.callout)
                }
            }
            .padding(26)
            .onAppear {
                permissionSnapshot = PermissionService().snapshot()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("权限")
                .font(.title2.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.ink)
            Text("麦克风、语音识别、辅助功能和隐私状态。")
                .foregroundStyle(ReadyTypeTheme.muted)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct PermissionRow: View {
    let title: String
    let description: String
    let status: PermissionStatus
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24)
                .foregroundStyle(ReadyTypeTheme.accentStrong)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(ReadyTypeTheme.muted)
            }

            Spacer()

            Text(statusText)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(status.isGranted ? ReadyTypeTheme.accentSoft : Color.orange.opacity(0.12), in: Capsule())
                .foregroundStyle(status.isGranted ? ReadyTypeTheme.accentStrong : ReadyTypeTheme.warning)
        }
        .padding(12)
        .background(ReadyTypeTheme.fieldStrong, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(ReadyTypeTheme.strokeSoft, lineWidth: 1)
        )
    }

    private var statusText: String {
        switch status {
        case .granted:
            return "已授权"
        case .denied:
            return "未授权"
        case .restricted:
            return "受限制"
        case .notDetermined:
            return "未询问"
        }
    }
}
