import Foundation

enum SelectionAction: String, CaseIterable, Equatable, Sendable {
    case shorten
    case expand
    case naturalize
    case formalize
    case organize
    case translateToEnglish
    case reply
}

struct ResolvedSelectionAction: Equatable, Sendable {
    let action: SelectionAction
    let spokenInstruction: String
}

enum SelectionIntentResolution: Equatable, Sendable {
    case ordinaryInput
    case selectionAction(ResolvedSelectionAction)
}

struct SelectionIntentResolver {
    private static let maximumInstructionLength = 240
    private static let maximumStandaloneCommandLength = 24

    func resolve(transcript: String, hasActiveSelection: Bool) -> SelectionIntentResolution {
        let instruction = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasActiveSelection,
              !instruction.isEmpty,
              instruction.count <= Self.maximumInstructionLength
        else {
            return .ordinaryInput
        }

        let normalized = Self.normalized(instruction)
        let hasExplicitTarget = Self.explicitTargetMarkers.contains(where: normalized.contains)
        let specificActions = Self.specificActions.filter {
            matches($0, normalized: normalized, hasExplicitTarget: hasExplicitTarget)
        }
        let matchesOrganize = matches(
            .organize,
            normalized: normalized,
            hasExplicitTarget: hasExplicitTarget
        )

        guard specificActions.count <= 1 else {
            return .ordinaryInput
        }

        if let action = specificActions.first {
            guard !matchesOrganize || Self.isOrganizeStyleModifier(normalized, action: action) else {
                return .ordinaryInput
            }
            return .selectionAction(
                ResolvedSelectionAction(action: action, spokenInstruction: instruction)
            )
        }

        if matchesOrganize {
            return .selectionAction(
                ResolvedSelectionAction(action: .organize, spokenInstruction: instruction)
            )
        }

        return .ordinaryInput
    }

    private func matches(
        _ action: SelectionAction,
        normalized: String,
        hasExplicitTarget: Bool
    ) -> Bool {
        let grammar = Self.grammar[action] ?? ActionGrammar(keywords: [], standalonePatterns: [])
        guard grammar.keywords.contains(where: normalized.contains) else {
            return false
        }

        if hasExplicitTarget {
            return hasImperativeShape(normalized, keywords: grammar.keywords)
        }

        guard normalized.count <= Self.maximumStandaloneCommandLength else {
            return false
        }

        return grammar.standalonePatterns.contains {
            Self.matches(pattern: $0, text: normalized)
        }
    }

    private func hasImperativeShape(_ text: String, keywords: [String]) -> Bool {
        if Self.commandPrefixes.contains(where: text.hasPrefix)
            || keywords.contains(where: text.hasPrefix) {
            return true
        }

        for marker in Self.explicitTargetMarkers where text.hasPrefix(marker) {
            let remainder = String(text.dropFirst(marker.count))
            guard let distance = keywords.compactMap({ remainder.distanceToFirstOccurrence(of: $0) }).min() else {
                continue
            }
            return distance <= 3
        }

        return false
    }

    private static let specificActions: [SelectionAction] = [
        .translateToEnglish,
        .reply,
        .shorten,
        .expand,
        .naturalize,
        .formalize
    ]

    private static let explicitTargetMarkers = [
        "这段话", "这段文字", "这句话", "这条消息", "这条内容", "这封邮件",
        "选中的文字", "选中文字", "所选文字", "上面这段", "把它", "让它"
    ]

    private static let commandPrefixes = [
        "请你帮我", "麻烦你", "请", "帮我", "麻烦", "替我", "把", "将", "让"
    ]

    private struct ActionGrammar {
        let keywords: [String]
        let standalonePatterns: [String]
    }

    private static let grammar: [SelectionAction: ActionGrammar] = [
        .shorten: ActionGrammar(
            keywords: ["缩短", "精简", "压缩", "改短", "写短", "短一点"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:缩短|精简|压缩|改短|写短)(?:一点|一些|到.{1,8})?[。！!]?$"#
            ]
        ),
        .expand: ActionGrammar(
            keywords: ["扩写", "展开", "详细一点", "写详细", "补充细节"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:扩写|展开|写详细|补充细节)(?:一点|一些|详细一点)?[。！!]?$"#,
                #"^(?:请|帮我|麻烦)?扩写详细一点[。！!]?$"#
            ]
        ),
        .naturalize: ActionGrammar(
            keywords: ["更自然", "自然一点", "口语化", "像人说的", "别太正式"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:改得|写得|变得)?(?:更自然|自然一点|口语化|像人说的|别太正式)(?:一点)?[。！!]?$"#
            ]
        ),
        .formalize: ActionGrammar(
            keywords: ["更正式", "正式一点", "更专业", "专业一点", "书面化"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:改得|写得|变得)?(?:更正式|正式一点|更专业|专业一点|书面化)(?:一点)?[。！!]?$"#
            ]
        ),
        .organize: ActionGrammar(
            keywords: ["整理", "润色", "理顺", "优化表达"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:整理|润色|理顺|优化表达)(?:一下|一点)?[。！!]?$"#
            ]
        ),
        .translateToEnglish: ActionGrammar(
            keywords: ["翻译成英文", "翻成英文", "译成英文", "翻译为英文"],
            standalonePatterns: [
                #"^(?:请|帮我|麻烦)?(?:把它)?(?:翻译成英文|翻成英文|译成英文|翻译为英文)[。！!]?$"#
            ]
        ),
        .reply: ActionGrammar(
            keywords: ["回复", "怎么回"],
            standalonePatterns: [
                #"^(?:请|帮我|替我|麻烦)?(?:回复|回)(?:一下|这条消息)?[。！!]?$"#,
                #"^(?:请|帮我|替我|麻烦)?怎么回(?:复)?[。！!]?$"#
            ]
        )
    ]

    private static func normalized(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: #"[\s，,。；;：:！？!?]+"#, with: "", options: .regularExpression)
    }

    private static func isOrganizeStyleModifier(_ text: String, action: SelectionAction) -> Bool {
        guard action == .naturalize || action == .formalize else {
            return false
        }

        let stylePhrases: [String]
        switch action {
        case .naturalize:
            stylePhrases = ["更自然", "自然一点", "口语化"]
        case .formalize:
            stylePhrases = ["更正式", "正式一点", "更专业", "专业一点", "书面化"]
        default:
            return false
        }

        return ["整理", "润色", "优化表达"].contains { organizeKeyword in
            stylePhrases.contains { stylePhrase in
                text.contains("\(organizeKeyword)得\(stylePhrase)")
                    || text.contains("\(organizeKeyword)成\(stylePhrase)")
            }
        }
    }

    private static func matches(pattern: String, text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}

private extension String {
    func distanceToFirstOccurrence(of value: String) -> Int? {
        guard let range = range(of: value) else {
            return nil
        }
        return distance(from: startIndex, to: range.lowerBound)
    }
}
