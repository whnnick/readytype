import Foundation

enum APIConnectionTestStatus: Equatable {
    case notTested
    case testing
    case success
    case missingKey
    case authenticationFailed
    case modelUnavailable
    case networkFailed
    case timeout
    case unknownFailure

    var title: String {
        switch self {
        case .notTested:
            return "尚未测试"
        case .testing:
            return "正在测试连接..."
        case .success:
            return "连接正常"
        case .missingKey:
            return "请先填写或保存 DeepSeek 密钥"
        case .authenticationFailed:
            return "DeepSeek 密钥无效或无权限"
        case .modelUnavailable:
            return "当前模型不可用"
        case .networkFailed:
            return "无法连接到服务"
        case .timeout:
            return "连接超时，请稍后重试"
        case .unknownFailure:
            return "测试失败"
        }
    }

    var role: StatusRole {
        switch self {
        case .notTested:
            return .neutral
        case .testing:
            return .progress
        case .success:
            return .success
        case .missingKey, .modelUnavailable, .networkFailed, .timeout:
            return .warning
        case .authenticationFailed, .unknownFailure:
            return .danger
        }
    }
}

struct APIConnectionTestState: Equatable {
    let status: APIConnectionTestStatus
    let detail: String?
    let model: String?
    let latencyMilliseconds: Int?

    static let notTested = APIConnectionTestState(
        status: .notTested,
        detail: "填写或保存 DeepSeek 连接信息后，可以先测试连接。",
        model: nil,
        latencyMilliseconds: nil
    )

    static let testing = APIConnectionTestState(
        status: .testing,
        detail: "正在发送最小测试请求，不会读取转写历史或剪贴板。",
        model: nil,
        latencyMilliseconds: nil
    )

    var displayDetail: String {
        if let detail {
            return detail
        }

        if status == .success, let model, let latencyMilliseconds {
            return "\(model) / \(latencyMilliseconds) ms"
        }

        return status.title
    }
}
