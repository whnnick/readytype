import Foundation

enum StatusRole: Equatable {
    case neutral
    case recording
    case progress
    case success
    case warning
    case danger
}

extension HotVocabularyStatus {
    var readyTypeStatusRole: StatusRole {
        switch self {
        case .notDownloaded:
            return .neutral
        case .checking:
            return .progress
        case .ready:
            return .success
        case .unavailable(let currentVersion):
            return currentVersion == nil ? .warning : .success
        }
    }

    var readyTypeTitle: String {
        switch self {
        case .notDownloaded:
            return "热门词尚未更新"
        case .checking:
            return "正在更新热门词"
        case .ready:
            return "热门词已自动更新"
        case .unavailable(let currentVersion):
            return currentVersion == nil ? "热门词暂时无法更新" : "热门词已可使用"
        }
    }

    var readyTypeDetail: String {
        switch self {
        case .notDownloaded:
            return "ReadyType 会在空闲时自动获取近期常见的人名、作品名和产品名。"
        case .checking:
            return "更新在后台完成，不影响语音输入。"
        case .ready:
            return "近期常见名称会作为低优先级提示，常用词仍然优先。"
        case .unavailable(let currentVersion):
            return currentVersion == nil
                ? "网络恢复后会自动重试，不影响现有语音输入。"
                : "这次更新未完成，ReadyType 会继续使用上次的有效内容。"
        }
    }

    var isChecking: Bool {
        if case .checking = self {
            return true
        }
        return false
    }
}

struct VoiceInputHUDPresentation: Equatable {
    let title: String
    let subtitle: String
}

enum VoiceInputHUDText {
    static func presentation(
        for state: RuntimeState,
        shortcut: VoiceShortcutConfiguration = .default
    ) -> VoiceInputHUDPresentation {
        switch state {
        case .idle:
            return VoiceInputHUDPresentation(title: "准备就绪", subtitle: "\(shortcut.displayName) 开始说话")
        case .recording:
            return VoiceInputHUDPresentation(title: "正在听", subtitle: "再次\(shortcut.displayName) 完成 · Esc 取消")
        case .transcribing:
            return VoiceInputHUDPresentation(title: "正在识别", subtitle: "保持当前输入框，马上就好")
        case .processingAI:
            return VoiceInputHUDPresentation(title: "正在整理", subtitle: "正在生成可直接使用的文本")
        case .pasted:
            return VoiceInputHUDPresentation(title: "已输入", subtitle: "已放到当前输入框")
        case .copiedFallback:
            return VoiceInputHUDPresentation(title: "已复制到剪贴板", subtitle: "可直接粘贴使用")
        case .error(let message):
            return VoiceInputHUDPresentation(title: "这次没有完成", subtitle: message)
        }
    }
}

extension RuntimeState {
    var readyTypeStatusRole: StatusRole {
        switch self {
        case .idle:
            return .neutral
        case .recording:
            return .recording
        case .transcribing, .processingAI:
            return .progress
        case .pasted:
            return .success
        case .copiedFallback:
            return .warning
        case .error:
            return .danger
        }
    }

    func readyTypeHomeStatusRole(
        localSpeechModelState: LocalSpeechModelState,
        isHighAccuracyEnabled: Bool
    ) -> StatusRole {
        if self == .idle,
           isHighAccuracyEnabled,
           localSpeechModelState == .warm {
            return .success
        }

        return readyTypeStatusRole
    }

    func readyTypeDisplayMessage(
        lastMessage: String? = nil,
        shortcut: VoiceShortcutConfiguration = .default
    ) -> String {
        if let lastMessage, !lastMessage.isEmpty {
            return lastMessage
        }

        switch self {
        case .idle:
            return "准备就绪"
        case .recording:
            return "正在语音输入，再次\(shortcut.displayName) 完成，Esc 取消"
        case .transcribing:
            return "正在识别"
        case .processingAI:
            return "正在整理"
        case .pasted:
            return "已粘贴"
        case .copiedFallback:
            return "已复制到剪贴板"
        case .error(let message):
            return message
        }
    }
}

extension LocalSpeechModelState {
    func readyTypeStatusRole(isHighAccuracyEnabled: Bool) -> StatusRole {
        guard isHighAccuracyEnabled else {
            return .neutral
        }

        switch self {
        case .notInstalled, .failed:
            return .danger
        case .downloadedCold:
            return .warning
        case .downloading, .warming:
            return .progress
        case .warm:
            return .success
        }
    }

    func readyTypeDisplayMessage(isHighAccuracyEnabled: Bool) -> String {
        guard isHighAccuracyEnabled else {
            return "高精度识别未启用"
        }

        switch self {
        case .notInstalled:
            return "高精度语音包未安装"
        case .downloading(let progress):
            let percentage = Int((min(max(progress, 0), 1) * 100).rounded())
            return "正在下载高精度语音包 \(percentage)%"
        case .downloadedCold:
            return "高精度语音包已安装，尚未准备好"
        case .warming:
            return "正在准备高精度识别"
        case .warm:
            return "高精度识别已准备好"
        case .failed(let reason):
            return "高精度识别暂不可用：\(reason)"
        }
    }
}

extension SpeechRecognitionRouteDecision {
    var readyTypeStatusRole: StatusRole {
        if fallbackReason != nil {
            return .warning
        }

        switch backend {
        case .fastSystem:
            return .neutral
        case .highAccuracyLocal:
            return .success
        }
    }

    var readyTypeDisplayMessage: String {
        if let fallbackReason, !fallbackReason.isEmpty {
            return fallbackReason
        }

        switch backend {
        case .fastSystem:
            return "本次使用极速识别"
        case .highAccuracyLocal:
            return "本次使用高精度识别"
        }
    }

    var readyTypeLastRunDisplayMessage: String {
        if let fallbackReason, !fallbackReason.isEmpty {
            return "上次识别：\(fallbackReason)"
        }

        switch backend {
        case .fastSystem:
            return "上次识别：极速识别"
        case .highAccuracyLocal:
            return "上次识别：高精度识别"
        }
    }
}

extension LocalSpeechModelUpdateStatus {
    var readyTypeStatusRole: StatusRole {
        switch self {
        case .notChecked, .notInstalled:
            return .neutral
        case .checking:
            return .progress
        case .upToDate:
            return .success
        case .updateAvailable, .unableToCheck:
            return .warning
        }
    }

    var readyTypeDisplayMessage: String {
        switch self {
        case .notChecked:
            return "尚未检查高精度语音包更新"
        case .checking:
            return "正在检查高精度语音包更新"
        case .notInstalled:
            return "安装高精度语音包后可检查更新"
        case .upToDate:
            return "已安装最新语音包，无需更新"
        case .updateAvailable(_, let latestManifest):
            if let sizeDescription = latestManifest.sizeDescription, !sizeDescription.isEmpty {
                return "发现新版高精度语音包（\(sizeDescription)）"
            }
            return "发现新版高精度语音包"
        case .unableToCheck(let reason):
            return reason
        }
    }
}
