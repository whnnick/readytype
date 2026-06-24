import Foundation

struct UserVocabularyLearningSuggestion: Equatable, Identifiable {
    var value: String
    var alias: String
    var kind: UserVocabularyKind
    var scopes: [UserVocabularyScope]
    var reason: String
    var confidence: Double

    var id: String {
        "\(value.normalizedSmartTermKey)<-\(alias.normalizedSmartTermKey)"
    }
}

struct UserVocabularyLearningService {
    private let minimumConfidence: Double

    init(minimumConfidence: Double = 0.82) {
        self.minimumConfidence = minimumConfidence
    }

    func suggestions(
        transcript: String,
        finalText: String?,
        scenario: OutputScenario,
        existingEntries: [UserVocabularyEntry],
        correctionCandidates: [TermCorrectionSuggestion]
    ) -> [UserVocabularyLearningSuggestion] {
        let sourceText = [transcript, finalText ?? ""].joined(separator: "\n")
        var seen: Set<String> = []

        return correctionCandidates.compactMap { candidate in
            guard let value = Self.cleaned(candidate.replacement),
                  let alias = Self.cleaned(candidate.original),
                  candidate.confidence >= minimumConfidence,
                  value.normalizedSmartTermKey != alias.normalizedSmartTermKey,
                  !Self.isAlreadySavedOrIgnored(value: value, alias: alias, in: existingEntries),
                  Self.contextSupportsLearning(value: value, alias: alias, sourceText: sourceText, scenario: scenario) else {
                return nil
            }

            let key = "\(value.normalizedSmartTermKey)<-\(alias.normalizedSmartTermKey)"
            guard !seen.contains(key) else {
                return nil
            }

            seen.insert(key)
            return UserVocabularyLearningSuggestion(
                value: value,
                alias: alias,
                kind: Self.inferredKind(for: value),
                scopes: Self.inferredScopes(sourceText: sourceText, scenario: scenario),
                reason: "以后按这个写法处理",
                confidence: candidate.confidence
            )
        }
    }

    private static func cleaned(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isAlreadySavedOrIgnored(
        value: String,
        alias: String,
        in entries: [UserVocabularyEntry]
    ) -> Bool {
        let valueKey = value.normalizedSmartTermKey
        let aliasKey = alias.normalizedSmartTermKey

        return entries.contains { entry in
            guard entry.value.normalizedSmartTermKey == valueKey else {
                return false
            }

            let savedAliasKeys = Set(entry.aliases.map(\.normalizedSmartTermKey))
            let ignoredAliasKeys = Set(entry.ignoredAliases.map(\.normalizedSmartTermKey))
            return savedAliasKeys.contains(aliasKey) || ignoredAliasKeys.contains(aliasKey)
        }
    }

    private static func contextSupportsLearning(
        value: String,
        alias: String,
        sourceText: String,
        scenario: OutputScenario
    ) -> Bool {
        if isTechnicalContext(sourceText, scenario: scenario) {
            return true
        }

        return !isOrdinaryEnglishAlias(alias) && !containsLatinScalar(value)
    }

    private static func inferredKind(for value: String) -> UserVocabularyKind {
        if containsLatinScalar(value) {
            return .technical
        }

        return value.count >= 4 ? .phrase : .general
    }

    private static func inferredScopes(sourceText: String, scenario: OutputScenario) -> [UserVocabularyScope] {
        if isTechnicalContext(sourceText, scenario: scenario) {
            return [.technical]
        }

        switch scenario {
        case .message:
            return [.chat]
        case .email:
            return [.email]
        case .aiTool:
            return [.aiTool]
        case .document:
            return [.document]
        case .generic, .note:
            return [.all]
        }
    }

    private static func isTechnicalContext(_ text: String, scenario: OutputScenario) -> Bool {
        let technicalSignals = [
            "ReadyType",
            "GitHub",
            "GitHub Actions",
            "README",
            "Docker",
            "Docker Compose",
            "Redis",
            "Nextcloud",
            "DeepSeek",
            "WhisperKit",
            "CoreML",
            "配置",
            "打包文件",
            "更新日志"
        ]
        let signalCount = technicalSignals.filter { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }.count

        return signalCount >= 2 && (scenario == .document || scenario == .aiTool || scenario == .generic)
    }

    private static func isOrdinaryEnglishAlias(_ alias: String) -> Bool {
        containsLatinScalar(alias)
    }

    private static func containsLatinScalar(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) ||
                (0x0061...0x007A).contains(Int(scalar.value))
        }
    }
}
