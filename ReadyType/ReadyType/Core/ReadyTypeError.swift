import Foundation

enum ReadyTypeError: Error, Equatable {
    case microphonePermissionMissing
    case speechRecognitionPermissionMissing
    case accessibilityPermissionMissing
    case keyboardMonitoringPermissionMissing
    case shortcutRegistrationFailed
    case recordingFailed(String)
    case recordingTooShort
    case transcriptionFailed(String)
    case transcriptionEmpty
    case invalidSettings(String)
    case deepSeekAPIKeyMissing
    case deepSeekAuthenticationFailed
    case deepSeekBaseURLUnreachable
    case deepSeekModelError(String)
    case deepSeekRateLimited
    case deepSeekServiceUnavailable(Int)
    case deepSeekTimeout
    case deepSeekUnexpectedResponse
    case keychainOperationFailed(String)
    case pasteFailed

    var userMessage: String {
        switch self {
        case .microphonePermissionMissing:
            return "需要麦克风权限才能语音输入。"
        case .speechRecognitionPermissionMissing:
            return "需要语音识别权限才能把语音转成文字。"
        case .accessibilityPermissionMissing:
            return "自动粘贴需要辅助功能权限。结果已复制到剪贴板。"
        case .keyboardMonitoringPermissionMissing:
            return "Esc 取消语音输入需要辅助功能权限，请在权限页开启。"
        case .shortcutRegistrationFailed:
            return "全局快捷键注册失败，请换一个快捷键。"
        case .recordingFailed(let reason):
            return "语音输入失败：\(reason)"
        case .recordingTooShort:
            return "语音太短，已忽略。"
        case .transcriptionFailed(let reason):
            return "语音识别失败：\(reason)"
        case .transcriptionEmpty:
            return "没有识别到语音文字。"
        case .invalidSettings(let reason):
            return reason
        case .deepSeekAPIKeyMissing:
            return "缺少 DeepSeek 密钥。"
        case .deepSeekAuthenticationFailed:
            return "DeepSeek 认证失败，请检查密钥。"
        case .deepSeekBaseURLUnreachable:
            return "DeepSeek 服务地址无法访问。"
        case .deepSeekModelError(let reason):
            return "DeepSeek 模型错误：\(reason)"
        case .deepSeekRateLimited:
            return "DeepSeek 当前请求受限，请稍后重试或检查账号额度。"
        case .deepSeekServiceUnavailable(let statusCode):
            return "DeepSeek 服务暂时不可用：HTTP \(statusCode)"
        case .deepSeekTimeout:
            return "DeepSeek 请求超时。"
        case .deepSeekUnexpectedResponse:
            return "DeepSeek 返回了异常响应。"
        case .keychainOperationFailed(let reason):
            return "钥匙串操作失败：\(reason)"
        case .pasteFailed:
            return "自动粘贴失败。结果已复制到剪贴板。"
        }
    }
}
