import SwiftUI

struct ReadyTypeAboutInfo: Equatable {
    let shortVersion: String
    let buildNumber: String
    let speechPackageDirectoryPath: String

    init(
        shortVersion: String,
        buildNumber: String,
        speechPackageDirectoryPath: String = LocalSpeechModelManager.defaultModelsDirectoryPath()
    ) {
        self.shortVersion = shortVersion
        self.buildNumber = buildNumber
        self.speechPackageDirectoryPath = speechPackageDirectoryPath
    }

    static func current(bundle: Bundle = .main) -> ReadyTypeAboutInfo {
        ReadyTypeAboutInfo(
            shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "未知",
            buildNumber: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "未知"
        )
    }

    var versionDisplay: String {
        "版本 \(shortVersion)"
    }

    var buildDisplay: String {
        "构建 \(buildNumber)"
    }

    var speechPackageStorageDescription: String {
        "高精度语音包保存在 \(speechPackageDirectoryPath)，可在设置里删除；以后需要更新时可重新下载。"
    }
}

struct AboutPane: View {
    @EnvironmentObject private var appState: AppState
    private let info: ReadyTypeAboutInfo

    init(info: ReadyTypeAboutInfo = .current()) {
        self.info = info
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                ReadyTypePanel("版本信息", subtitle: "ReadyType 当前为 1.0.0 正式版候选。") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(info.versionDisplay, systemImage: "number")
                        Label(info.buildDisplay, systemImage: "hammer")
                        Label("中文优先的 macOS 语音输入工具。", systemImage: "mic")
                        Label("\(appState.voiceShortcut.displayName) 开始说话，再次\(appState.voiceShortcut.displayName) 完成输入；Esc 取消。", systemImage: "keyboard")
                    }
                    .font(.callout)
                }

                ReadyTypePanel("高精度语音包", subtitle: "复杂内容想更准时可一次性下载，可随时删除。") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(info.speechPackageStorageDescription, systemImage: "externaldrive")
                        Label("自动选择会优先保证响应速度；长文、邮件、文档和术语较多时再提高准确率。", systemImage: "switch.2")
                        Label("下载后会在后台准备，完成后显示已准备好，不弹窗打断输入。", systemImage: "checkmark.circle")
                    }
                    .font(.callout)
                }

                ReadyTypePanel("隐私边界", subtitle: "默认不保存完整转写历史。") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("直接转文字不会使用 DeepSeek。", systemImage: "text.cursor")
                        Label("整理、翻译和写给 AI 只发送当前这次文本。", systemImage: "lock.shield")
                        Label("DeepSeek 密钥保存在 macOS 钥匙串。", systemImage: "key")
                    }
                    .font(.callout)
                }
            }
            .padding(26)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("关于 ReadyType")
                .font(.title2.weight(.semibold))
                .foregroundStyle(ReadyTypeTheme.ink)
            Text("版本、高精度语音包位置和隐私说明。")
                .foregroundStyle(ReadyTypeTheme.muted)
        }
    }
}
