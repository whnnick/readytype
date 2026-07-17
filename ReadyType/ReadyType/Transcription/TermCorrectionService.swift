import Foundation

struct TermCorrectionSuggestion: Equatable {
    var original: String
    var replacement: String
    var confidence: Double
    var source: SmartTermSource = .builtIn
    var scopes: [UserVocabularyScope] = [.all]

    static func == (lhs: TermCorrectionSuggestion, rhs: TermCorrectionSuggestion) -> Bool {
        lhs.original == rhs.original &&
            lhs.replacement == rhs.replacement &&
            lhs.confidence == rhs.confidence
    }
}

struct TermCorrectionService {
    private let dictionary: SmartTermDictionary

    init(dictionary: SmartTermDictionary) {
        self.dictionary = dictionary
    }

    func suggestions(for text: String) -> [TermCorrectionSuggestion] {
        let rawSuggestions = dictionary.terms
            .flatMap { suggestions(for: $0, in: text) }

        return Self.deduplicated(rawSuggestions)
            .sorted { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.replacement.localizedCaseInsensitiveCompare(rhs.replacement) == .orderedAscending
                }
                return lhs.confidence > rhs.confidence
            }
    }

    private static func deduplicated(_ suggestions: [TermCorrectionSuggestion]) -> [TermCorrectionSuggestion] {
        var byKey: [String: TermCorrectionSuggestion] = [:]

        for suggestion in suggestions {
            let key = "\(suggestion.original.normalizedSmartTermKey)->\(suggestion.replacement.normalizedSmartTermKey)"
            if let existing = byKey[key] {
                guard shouldReplace(existing: existing, with: suggestion) else {
                    continue
                }
            }
            byKey[key] = suggestion
        }

        return Array(byKey.values)
    }

    private static func shouldReplace(
        existing: TermCorrectionSuggestion,
        with suggestion: TermCorrectionSuggestion
    ) -> Bool {
        if suggestion.confidence != existing.confidence {
            return suggestion.confidence > existing.confidence
        }

        return scopeSpecificityScore(suggestion.scopes) > scopeSpecificityScore(existing.scopes)
    }

    private static func scopeSpecificityScore(_ scopes: [UserVocabularyScope]) -> Int {
        guard !scopes.isEmpty else {
            return 0
        }

        let scopedCount = scopes.filter { $0 != .all }.count
        if scopedCount == 0 {
            return 0
        }

        return 100 - scopes.count
    }

    private func suggestions(for term: SmartTerm, in text: String) -> [TermCorrectionSuggestion] {
        guard term.allowsPostRecognitionCorrection,
              term.value.count > 3 || !term.aliases.isEmpty else {
            return []
        }

        return aliases(for: term)
            .filter { containsAlias($0.original, in: text) }
            .map { alias in
                TermCorrectionSuggestion(
                    original: alias.original,
                    replacement: term.value,
                    confidence: alias.confidence,
                    source: term.source,
                    scopes: alias.scopes
                )
            }
    }

    private func aliases(for term: SmartTerm) -> [(original: String, confidence: Double, scopes: [UserVocabularyScope])] {
        var aliases = term.aliases.map {
            (original: $0, confidence: term.aliasConfidence, scopes: term.scopes)
        }

        let lowercaseValue = term.value.lowercased()
        if term.source == .userDefined, lowercaseValue != term.value {
            aliases.append((original: lowercaseValue, confidence: 0.98, scopes: term.scopes))
        }

        switch term.value.normalizedSmartTermKey {
        case "readytype":
            aliases.append(contentsOf: [
                (original: "Ready Tap", confidence: 0.88, scopes: term.scopes),
                (original: "ReadyTap", confidence: 0.88, scopes: term.scopes),
                (original: "Ready Tape", confidence: 0.86, scopes: term.scopes),
                (original: "Reddit Tab", confidence: 0.88, scopes: [.technical]),
                (original: "Reddit Type", confidence: 0.88, scopes: [.technical]),
                (original: "Redis Type", confidence: 0.78, scopes: term.scopes)
            ])
        case "deepseek":
            aliases.append(contentsOf: [
                (original: "DeepSeq", confidence: 0.86, scopes: term.scopes),
                (original: "Deep Seek", confidence: 0.84, scopes: term.scopes),
                (original: "Deep Seq", confidence: 0.84, scopes: term.scopes)
            ])
        case "redis":
            aliases.append(contentsOf: [
                (original: "瑞迪斯", confidence: 0.9, scopes: term.scopes),
                (original: "Reddit", confidence: 0.78, scopes: term.scopes)
            ])
        case "kubernetes":
            aliases.append(contentsOf: [
                (original: "库伯内提斯", confidence: 0.86, scopes: term.scopes),
                (original: "k8s", confidence: 0.82, scopes: term.scopes)
            ])
        case "docker":
            aliases.append(("多克尔", 0.82, term.scopes))
        case "报价单":
            aliases.append(("报表单", 0.82, term.scopes))
        case "灰度发布":
            aliases.append(("回头发布", 0.82, term.scopes))
        default:
            break
        }

        return aliases
    }

    private func containsAlias(_ alias: String, in text: String) -> Bool {
        var searchRange = text.startIndex..<text.endIndex

        while let range = text.range(
            of: alias,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if Self.hasValidBoundaries(range, alias: alias, in: text) {
                return true
            }

            guard range.upperBound < text.endIndex else {
                break
            }
            searchRange = range.upperBound..<text.endIndex
        }

        return false
    }

    private static func hasValidBoundaries(
        _ range: Range<String.Index>,
        alias: String,
        in text: String
    ) -> Bool {
        guard alias.containsLatinScalar else {
            return true
        }

        let hasValidLeadingBoundary = range.lowerBound == text.startIndex ||
            !text[text.index(before: range.lowerBound)].isLatinLetterOrNumber
        let hasValidTrailingBoundary = range.upperBound == text.endIndex ||
            !text[range.upperBound].isLatinLetterOrNumber

        return hasValidLeadingBoundary && hasValidTrailingBoundary
    }
}

private extension Character {
    var isLatinLetterOrNumber: Bool {
        unicodeScalars.allSatisfy { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) ||
                (0x0061...0x007A).contains(Int(scalar.value)) ||
                (0x0030...0x0039).contains(Int(scalar.value))
        }
    }
}

private extension String {
    var containsLatinScalar: Bool {
        unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) ||
                (0x0061...0x007A).contains(Int(scalar.value))
        }
    }
}
