import Foundation

struct SmartTerm: Equatable, Hashable {
    var value: String
    var source: SmartTermSource
    var weight: Double
    var aliases: [String] = []
    var scopes: [UserVocabularyScope] = [.all]
    var aliasConfidence: Double = 0.82
    var allowsPostRecognitionCorrection: Bool = true
}

enum SmartTermSource: String, Codable {
    case builtIn
    case packageName
    case projectFile
    case userDefined
    case recentCorrection
    case trending
}

struct SmartTermDictionary: Equatable {
    var terms: [SmartTerm]

    init(terms: [SmartTerm] = []) {
        self.terms = Self.deduplicated(terms)
    }

    private static func deduplicated(_ terms: [SmartTerm]) -> [SmartTerm] {
        var byKey: [String: SmartTerm] = [:]

        for term in terms {
            let key = term.value.normalizedSmartTermKey
            guard !key.isEmpty else {
                continue
            }

            if let existing = byKey[key] {
                byKey[key] = betterTerm(existing, term)
            } else {
                byKey[key] = term
            }
        }

        return Array(byKey.values)
    }

    private static func betterTerm(_ lhs: SmartTerm, _ rhs: SmartTerm) -> SmartTerm {
        let lhsScore = lhs.weight + lhs.source.basePriority
        let rhsScore = rhs.weight + rhs.source.basePriority
        let preferred = rhsScore > lhsScore ? rhs : lhs
        let fallback = rhsScore > lhsScore ? lhs : rhs

        return SmartTerm(
            value: preferred.value,
            source: preferred.source,
            weight: preferred.weight,
            aliases: mergedAliases(preferred.aliases + fallback.aliases, excluding: preferred.value),
            scopes: mergedScopes(preferred.scopes + fallback.scopes),
            aliasConfidence: max(preferred.aliasConfidence, fallback.aliasConfidence),
            allowsPostRecognitionCorrection: preferred.allowsPostRecognitionCorrection
        )
    }

    private static func mergedAliases(_ aliases: [String], excluding value: String) -> [String] {
        let valueKey = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen: Set<String> = []
        var result: [String] = []

        for alias in aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.lowercased()
            guard !trimmed.isEmpty, !key.isEmpty, key != valueKey, !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(trimmed)
        }

        return result
    }

    private static func mergedScopes(_ scopes: [UserVocabularyScope]) -> [UserVocabularyScope] {
        var seen: Set<UserVocabularyScope> = []
        var result: [UserVocabularyScope] = []

        for scope in scopes where !seen.contains(scope) {
            seen.insert(scope)
            result.append(scope)
        }

        return result.isEmpty ? [.all] : result
    }

    func mergingUserVocabulary(_ entries: [UserVocabularyEntry]) -> SmartTermDictionary {
        SmartTermDictionary(terms: terms + entries.map(\.smartTerm))
    }

    func mergingHotVocabulary(
        _ verifiedPack: VerifiedHotVocabularyPack,
        now: Date = Date()
    ) -> SmartTermDictionary {
        let activeTerms = verifiedPack.pack.terms
            .filter { $0.expiresAt.map { now < $0 } ?? true }
            .map { term in
                SmartTerm(
                    value: term.value,
                    source: .trending,
                    weight: min(max(term.weight, 0), 100),
                    aliases: term.aliases,
                    scopes: term.scopes,
                    aliasConfidence: 0.9,
                    allowsPostRecognitionCorrection: false
                )
            }
        return SmartTermDictionary(terms: terms + activeTerms)
    }
}

enum SmartTermCatalog {
    static let productTerms = [
        SmartTerm(value: "ReadyType", source: .userDefined, weight: 100, aliases: ["Ready Tap", "ReadyTap", "Ready Tape", "Reddit Tab", "Reddit Type", "Redis Type"]),
        SmartTerm(value: "DeepSeek", source: .builtIn, weight: 80, aliases: ["Deep Seek", "DeepSeq", "Deep Seq", "DeepSig"]),
        SmartTerm(value: "Option", source: .builtIn, weight: 50),
        SmartTerm(value: "Esc", source: .builtIn, weight: 50),
        SmartTerm(value: "Command", source: .builtIn, weight: 50),
        SmartTerm(value: "Control", source: .builtIn, weight: 50),
        SmartTerm(value: "高精度语音包", source: .builtIn, weight: 48, aliases: ["高精度语言包", "高精度银包", "高精度音包"]),
        SmartTerm(value: "极速识别", source: .builtIn, weight: 48, aliases: ["急速识别"]),
        SmartTerm(value: "语音包", source: .builtIn, weight: 47, aliases: ["语言包", "银包"])
    ]

    static let technicalTerms = [
        SmartTerm(value: "GitHub", source: .builtIn, weight: 78, aliases: ["get up", "github"]),
        SmartTerm(value: "Docker", source: .builtIn, weight: 76),
        SmartTerm(value: "Docker Compose", source: .builtIn, weight: 76, aliases: ["docker compass", "docker compose"]),
        SmartTerm(value: "Kubernetes", source: .builtIn, weight: 76, aliases: ["uber nights", "k8s"]),
        SmartTerm(value: "Redis", source: .packageName, weight: 74, aliases: ["瑞迪斯"]),
        SmartTerm(value: "Nextcloud", source: .projectFile, weight: 72, aliases: ["Next Cloud", "NextCloud"]),
        SmartTerm(value: "Postgres", source: .packageName, weight: 68),
        SmartTerm(value: "Cursor", source: .builtIn, weight: 62),
        SmartTerm(value: "Xcode", source: .builtIn, weight: 60),
        SmartTerm(value: "WhisperKit", source: .builtIn, weight: 58),
        SmartTerm(value: "GitHub Actions", source: .builtIn, weight: 56, aliases: ["get hot action", "get hot actions", "get hub action", "get hub actions", "DeepHub Action", "DeepHub Actions", "github action", "github actions"]),
        SmartTerm(value: "README", source: .builtIn, weight: 55),
        SmartTerm(value: "API", source: .builtIn, weight: 54),
        SmartTerm(value: "CoreML", source: .builtIn, weight: 52)
    ]

    static let workPhraseTerms = [
        SmartTerm(value: "待办事项", source: .builtIn, weight: 47, aliases: ["代办事项"]),
        SmartTerm(value: "大小写", source: .builtIn, weight: 47, aliases: ["大消息"]),
        SmartTerm(value: "报价单", source: .builtIn, weight: 46, aliases: ["报表单"]),
        SmartTerm(value: "复测", source: .builtIn, weight: 46, aliases: ["复册"]),
        SmartTerm(value: "近音词", source: .builtIn, weight: 46, aliases: ["禁音词", "尽因此"]),
        SmartTerm(value: "权限说明", source: .builtIn, weight: 45, aliases: ["全线说明"]),
        SmartTerm(value: "失败样本归类", source: .builtIn, weight: 45, aliases: ["失败用本棍类"]),
        SmartTerm(value: "灰度发布", source: .builtIn, weight: 44, aliases: ["回头发布"]),
        SmartTerm(value: "更新日志", source: .builtIn, weight: 44, aliases: ["更新日誌", "更新误诸", "更新日课"])
    ]

    static var defaultTerms: [SmartTerm] {
        productTerms + technicalTerms + workPhraseTerms
    }
}

extension SmartTermDictionary {
    static let readyTypeDefault = SmartTermDictionary(terms: SmartTermCatalog.defaultTerms)
}

extension SmartTermSource {
    var basePriority: Double {
        switch self {
        case .userDefined:
            return 1_000
        case .recentCorrection:
            return 700
        case .projectFile:
            return 500
        case .packageName:
            return 300
        case .builtIn:
            return 100
        case .trending:
            return -1
        }
    }
}

extension String {
    var normalizedSmartTermKey: String {
        lowercased()
            .filter { character in
                character.isLetter || character.isNumber
            }
    }
}
