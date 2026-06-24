import Foundation

enum SpeechRecognitionMode: String, CaseIterable, Codable, Equatable {
    case automatic
    case fastSystem
    case highAccuracyLocal

    var displayName: String {
        switch self {
        case .automatic:
            return "自动选择"
        case .fastSystem:
            return "极速识别"
        case .highAccuracyLocal:
            return "高精度识别"
        }
    }

    var userDescription: String {
        switch self {
        case .automatic:
            return "推荐默认使用。短句、聊天和搜索优先速度；长文、邮件、文档和术语较多时自动提高准确率。"
        case .fastSystem:
            return "适合几句话以内的日常输入，响应最快。"
        case .highAccuracyLocal:
            return "适合长文、邮件、文档、英文夹杂和专业词较多的内容。"
        }
    }
}
