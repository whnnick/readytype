import Foundation

enum OutputMode: String, CaseIterable, Identifiable, Codable {
    case dictation
    case aiCleanup
    case translationToEnglish
    case promptOutput

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dictation:
            return "直接转文字"
        case .aiCleanup:
            return "整理成文"
        case .translationToEnglish:
            return "翻译成英文"
        case .promptOutput:
            return "写给 AI"
        }
    }

    var userDescription: String {
        switch self {
        case .dictation:
            return "基本按你说的转成文字，不调用 DeepSeek，也不主动润色。"
        case .aiCleanup:
            return "把口语整理成可以直接发送或保存的文本，会按写作场景调整格式。"
        case .translationToEnglish:
            return "把中文口述输出成自然英文，会按写作场景调整格式。"
        case .promptOutput:
            return "把你的口述整理成清楚的任务说明，适合发给 AI 工具继续处理。"
        }
    }

    var requiresAI: Bool {
        switch self {
        case .dictation:
            return false
        case .aiCleanup, .translationToEnglish, .promptOutput:
            return true
        }
    }
}
