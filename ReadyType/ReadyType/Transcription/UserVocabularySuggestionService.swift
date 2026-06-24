import Foundation

struct UserVocabularySuggestion: Equatable, Identifiable {
    var value: String
    var kind: UserVocabularyKind
    var aliases: [String]
    var scopes: [UserVocabularyScope] = [.all]
    var confidence: Double = 0.82
    var reason: String

    var id: String {
        "\(value.normalizedSmartTermKey)<-\(aliases.joined(separator: "|").normalizedSmartTermKey)"
    }
}

struct UserVocabularySuggestionService {
    private let dictionary: SmartTermDictionary

    init(dictionary: SmartTermDictionary) {
        self.dictionary = dictionary
    }

    func suggestions(
        transcript: String,
        finalText: String?,
        scenario: OutputScenario = .generic,
        existingEntries: [UserVocabularyEntry]
    ) -> [UserVocabularySuggestion] {
        let sourceText = [transcript, finalText ?? ""].joined(separator: "\n")
        let correctionService = TermCorrectionService(dictionary: dictionary)
        let correctionCandidates = correctionService
            .suggestions(for: sourceText)
            .filter { !isSiblingAliasAlreadyCovered($0, existingEntries: existingEntries) }

        return UserVocabularyLearningService()
            .suggestions(
                transcript: transcript,
                finalText: finalText,
                scenario: scenario,
                existingEntries: existingEntries,
                correctionCandidates: correctionCandidates
            )
            .map { suggestion in
                UserVocabularySuggestion(
                    value: suggestion.value,
                    kind: suggestion.kind,
                    aliases: [suggestion.alias],
                    scopes: suggestion.scopes,
                    confidence: suggestion.confidence,
                    reason: suggestion.reason
                )
            }
    }

    private func isSiblingAliasAlreadyCovered(
        _ candidate: TermCorrectionSuggestion,
        existingEntries: [UserVocabularyEntry]
    ) -> Bool {
        let valueKey = candidate.replacement.normalizedSmartTermKey
        let aliasKey = candidate.original.normalizedSmartTermKey
        guard !valueKey.isEmpty, !aliasKey.isEmpty else {
            return false
        }

        guard let existingEntry = existingEntries.first(where: {
            $0.value.normalizedSmartTermKey == valueKey
        }) else {
            return false
        }

        let coveredAliasKeys = Set((existingEntry.aliases + existingEntry.ignoredAliases).map(\.normalizedSmartTermKey))
        if coveredAliasKeys.contains(aliasKey) {
            return true
        }

        guard !coveredAliasKeys.isEmpty,
              let dictionaryTerm = dictionary.terms.first(where: {
                  $0.value.normalizedSmartTermKey == valueKey
              }) else {
            return false
        }

        let knownAliasKeys = Set(dictionaryTerm.aliases.map(\.normalizedSmartTermKey))
        return knownAliasKeys.contains(aliasKey) && !coveredAliasKeys.isDisjoint(with: knownAliasKeys)
    }
}
