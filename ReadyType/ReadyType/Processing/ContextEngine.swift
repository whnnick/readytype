import Foundation

enum AppProfile: String, CaseIterable, Equatable {
    case generic
    case personalChat
    case workChat
    case email
    case note
    case document
    case aiTool

    var scenario: OutputScenario {
        switch self {
        case .generic:
            return .generic
        case .personalChat, .workChat:
            return .message
        case .email:
            return .email
        case .note:
            return .note
        case .document:
            return .document
        case .aiTool:
            return .aiTool
        }
    }
}

enum InputIntent: String, Equatable {
    case dictation
    case composeMessage
    case composeEmail
    case captureNote
    case composeDocument
    case instructAI
}

enum OutputTone: String, Equatable {
    case neutral
    case personal
    case work
    case professional
    case structured
    case instructional
}

enum ContextDecisionConfidence: String, Equatable {
    case high
    case medium
    case fallback
}

enum ContextReason: String, Hashable {
    case manualSelection
    case windowTitle
    case bundleIdentifier
    case transcriptSemantics
    case fallback
}

struct ContextRequest: Equatable {
    let bundleIdentifier: String?
    let windowTitle: String?
    let transcript: String?
    let manualScenario: OutputScenario?

    init(
        bundleIdentifier: String? = nil,
        windowTitle: String? = nil,
        transcript: String? = nil,
        manualScenario: OutputScenario? = nil
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.transcript = transcript
        self.manualScenario = manualScenario
    }
}

struct ContextDecision: Equatable {
    let appProfile: AppProfile
    let scenario: OutputScenario
    let chatTone: ChatTone
    let intent: InputIntent
    let outputTone: OutputTone
    let confidence: ContextDecisionConfidence
    let reasons: Set<ContextReason>
}

struct ContextEngine {
    private let catalog = AppProfileCatalog()

    func resolve(_ request: ContextRequest) -> ContextDecision {
        let appMatch = catalog.match(
            bundleIdentifier: request.bundleIdentifier,
            windowTitle: request.windowTitle
        )

        if let manualScenario = request.manualScenario {
            return makeDecision(
                appProfile: appMatch?.profile ?? .generic,
                scenario: manualScenario,
                chatTone: catalog.chatTone(
                    bundleIdentifier: request.bundleIdentifier,
                    windowTitle: request.windowTitle
                ),
                confidence: .high,
                reasons: [.manualSelection]
            )
        }

        if let appMatch {
            return makeDecision(
                appProfile: appMatch.profile,
                scenario: appMatch.profile.scenario,
                chatTone: appMatch.profile.chatTone,
                confidence: .high,
                reasons: [appMatch.reason]
            )
        }

        if let semanticScenario = TranscriptScenarioClassifier.infer(request.transcript) {
            return makeDecision(
                appProfile: .generic,
                scenario: semanticScenario,
                chatTone: catalog.chatTone(
                    bundleIdentifier: request.bundleIdentifier,
                    windowTitle: request.windowTitle
                ),
                confidence: .medium,
                reasons: [.transcriptSemantics]
            )
        }

        return makeDecision(
            appProfile: .generic,
            scenario: .generic,
            chatTone: .default,
            confidence: .fallback,
            reasons: [.fallback]
        )
    }

    private func makeDecision(
        appProfile: AppProfile,
        scenario: OutputScenario,
        chatTone: ChatTone,
        confidence: ContextDecisionConfidence,
        reasons: Set<ContextReason>
    ) -> ContextDecision {
        let effectiveChatTone = scenario == .message ? chatTone : .default
        return ContextDecision(
            appProfile: appProfile,
            scenario: scenario,
            chatTone: effectiveChatTone,
            intent: scenario.intent,
            outputTone: scenario.outputTone(chatTone: effectiveChatTone),
            confidence: confidence,
            reasons: reasons
        )
    }
}

struct AppProfileCatalog {
    struct Match: Equatable {
        let profile: AppProfile
        let reason: ContextReason
    }

    func match(bundleIdentifier: String?, windowTitle: String?) -> Match? {
        let bundle = normalized(bundleIdentifier)
        let title = normalized(windowTitle)

        if containsAny(title, ["chatgpt", "claude", "deepseek", "codex", "cursor"]) {
            return Match(profile: .aiTool, reason: .windowTitle)
        }
        if containsAny(title, ["gmail", "outlook", "mail"]) {
            return Match(profile: .email, reason: .windowTitle)
        }
        if containsAny(bundle, ["mail", "outlook"]) {
            return Match(profile: .email, reason: .bundleIdentifier)
        }
        if containsAny(title, ["google docs", "word", "pages", "document"]) {
            return Match(profile: .document, reason: .windowTitle)
        }
        if containsAny(bundle, ["microsoft.word", "pages", "xcode"]) {
            return Match(profile: .document, reason: .bundleIdentifier)
        }
        if containsAny(title, ["notion", "obsidian", "notes"]) {
            return Match(profile: .note, reason: .windowTitle)
        }
        if containsAny(bundle, ["notes", "notion", "obsidian"]) {
            return Match(profile: .note, reason: .bundleIdentifier)
        }
        if containsAny(bundle, ["wechat", "xinwechat"]) {
            return Match(profile: .personalChat, reason: .bundleIdentifier)
        }
        if containsAny(bundle, ["feishu", "larksuite", "slack", "discord"]) {
            return Match(profile: .workChat, reason: .bundleIdentifier)
        }
        if containsAny(bundle, ["chatgpt", "claude", "deepseek", "codex", "cursor", "todesktop"]) {
            return Match(profile: .aiTool, reason: .bundleIdentifier)
        }

        return nil
    }

    func chatTone(bundleIdentifier: String?, windowTitle: String?) -> ChatTone {
        let bundle = normalized(bundleIdentifier)
        let title = normalized(windowTitle)

        if containsAny(bundle, ["wechat", "xinwechat", "qq", "telegram", "whatsapp", "messages"]) ||
            title.contains("微信") {
            return .personal
        }
        if containsAny(bundle, ["feishu", "larksuite", "slack", "teams", "discord"]) {
            return .work
        }
        return .default
    }

    private func normalized(_ value: String?) -> String {
        (value ?? "").lowercased()
    }

    private func containsAny(_ value: String, _ candidates: [String]) -> Bool {
        candidates.contains(where: value.contains)
    }
}

private extension AppProfile {
    var chatTone: ChatTone {
        switch self {
        case .personalChat:
            return .personal
        case .workChat:
            return .work
        default:
            return .default
        }
    }
}

private extension OutputScenario {
    var intent: InputIntent {
        switch self {
        case .generic:
            return .dictation
        case .message:
            return .composeMessage
        case .email:
            return .composeEmail
        case .note:
            return .captureNote
        case .document:
            return .composeDocument
        case .aiTool:
            return .instructAI
        }
    }

    func outputTone(chatTone: ChatTone) -> OutputTone {
        switch self {
        case .generic:
            return .neutral
        case .message:
            switch chatTone {
            case .default:
                return .neutral
            case .personal:
                return .personal
            case .work:
                return .work
            }
        case .email, .document:
            return .professional
        case .note:
            return .structured
        case .aiTool:
            return .instructional
        }
    }
}

private enum TranscriptScenarioClassifier {
    static func infer(_ transcript: String?) -> OutputScenario? {
        let text = (transcript ?? "").lowercased()
        guard !text.isEmpty else {
            return nil
        }

        if text.contains("写一封邮件") ||
            text.contains("写封邮件") ||
            text.contains("发一封邮件") ||
            text.contains("发封邮件") ||
            text.contains("发邮件") ||
            text.contains("邮件给") ||
            text.contains("给") && text.contains("发") && text.contains("邮件") ||
            text.contains("email") ||
            text.contains("e-mail") {
            return .email
        }

        if text.contains("给 ai") ||
            text.contains("让 ai") ||
            text.contains("chatgpt") ||
            text.contains("claude") ||
            text.contains("deepseek") ||
            text.contains("cursor") ||
            text.contains("codex") {
            return .aiTool
        }

        if text.contains("回复他") ||
            text.contains("回他说") ||
            text.contains("发消息") ||
            text.contains("微信消息") ||
            text.contains("微信") ||
            hasChatSendInstruction(text) ||
            text.contains("发给") && (text.contains("沟通内容") || text.contains("项目沟通") || text.contains("消息")) ||
            text.contains("给") && text.contains("发") && text.contains("消息") ||
            text.contains("slack") {
            return .message
        }

        if text.contains("待办") ||
            text.contains("todo") ||
            text.contains("to-do") ||
            text.contains("整理成笔记") ||
            text.contains("记一下") ||
            text.contains("会议纪要") {
            return .note
        }

        if text.contains("文档") ||
            text.contains("报告") ||
            text.contains("方案") ||
            text.contains("说明书") ||
            text.contains("document") {
            return .document
        }

        return nil
    }

    private static func hasChatSendInstruction(_ text: String) -> Bool {
        let patterns = [
            #"^\s*发给[\p{Han}A-Za-z0-9_·]{1,12}([，,：:\s]|$)"#,
            #"^\s*给[\p{Han}A-Za-z0-9_·]{1,12}发(?!票)"#
        ]
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }
            return regex.firstMatch(in: text, range: range) != nil
        }
    }
}
