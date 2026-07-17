import Foundation

struct ContextualVocabularyRequest: Equatable {
    var scenario: OutputScenario
    var frontmostAppBundleIdentifier: String?
    var projectRoot: URL?
    var transcriptPrefix: String
    var maximumTerms: Int
    var timeoutMilliseconds: Int

    init(
        scenario: OutputScenario,
        frontmostAppBundleIdentifier: String? = nil,
        projectRoot: URL? = nil,
        transcriptPrefix: String = "",
        maximumTerms: Int = 60,
        timeoutMilliseconds: Int = 80
    ) {
        self.scenario = scenario
        self.frontmostAppBundleIdentifier = frontmostAppBundleIdentifier
        self.projectRoot = projectRoot
        self.transcriptPrefix = transcriptPrefix
        self.maximumTerms = maximumTerms
        self.timeoutMilliseconds = timeoutMilliseconds
    }
}

struct ContextualVocabularyProvider {
    private let dictionary: SmartTermDictionary
    private let artificialDelayNanoseconds: UInt64

    init(dictionary: SmartTermDictionary, artificialDelayNanoseconds: UInt64 = 0) {
        self.dictionary = dictionary
        self.artificialDelayNanoseconds = artificialDelayNanoseconds
    }

    func terms(for request: ContextualVocabularyRequest) async -> [String] {
        let timeoutNanoseconds = UInt64(max(request.timeoutMilliseconds, 0)) * 1_000_000
        guard timeoutNanoseconds > 0 else {
            return []
        }

        return await withTaskGroup(of: [String].self) { group in
            group.addTask {
                if artificialDelayNanoseconds > 0 {
                    do {
                        try await Task.sleep(nanoseconds: artificialDelayNanoseconds)
                    } catch {
                        return []
                    }
                }
                guard !Task.isCancelled else { return [] }
                return rankedTerms(for: request)
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return []
            }

            let result = await group.next() ?? []
            group.cancelAll()
            return result
        }
    }

    func termsImmediately(for request: ContextualVocabularyRequest) -> [String] {
        rankedTerms(for: request)
    }

    private func rankedTerms(for request: ContextualVocabularyRequest) -> [String] {
        let limit = effectiveLimit(for: request)
        guard limit > 0 else {
            return []
        }

        let context = RankingContext(request: request)

        let ranked = dictionary.terms
            .filter { $0.isAllowed(for: context) }
            .map { term in
                RankedSmartTerm(
                    value: term.value,
                    sortKey: term.value.lowercased(),
                    score: score(term, for: context),
                    source: term.source
                )
            }
            .filter { $0.score > 0 }
            .sorted()

        var terms: [String] = []
        var trendingCount = 0
        let trendingLimit = min(20, limit)
        for term in ranked where terms.count < limit {
            if term.source == .trending {
                guard trendingCount < trendingLimit else { continue }
                trendingCount += 1
            }
            terms.append(term.value)
        }
        return terms
    }

    private func effectiveLimit(for request: ContextualVocabularyRequest) -> Int {
        let hardCappedLimit = min(max(request.maximumTerms, 0), 100)
        guard request.scenario == .message else {
            return hardCappedLimit
        }

        return min(hardCappedLimit, 2)
    }

    private func score(_ term: SmartTerm, for context: RankingContext) -> Double {
        var score = term.weight + term.source.basePriority

        if context.isTechnical {
            switch term.source {
            case .packageName:
                score += 80
            case .projectFile:
                score += 70
            case .builtIn:
                score += 30
            case .userDefined, .recentCorrection:
                score += 40
            case .trending:
                break
            }
        }

        if context.normalizedTranscriptPrefix.contains(term.value.normalizedSmartTermKey) {
            score += 250
        }

        if term.value.count <= 2 && term.source != .userDefined {
            score -= 50
        }

        return score
    }
}

private struct RankedSmartTerm: Comparable {
    var value: String
    var sortKey: String
    var score: Double
    var source: SmartTermSource

    static func < (lhs: RankedSmartTerm, rhs: RankedSmartTerm) -> Bool {
        if lhs.score == rhs.score {
            return lhs.sortKey < rhs.sortKey
        }
        return lhs.score > rhs.score
    }
}

private struct RankingContext {
    var normalizedTranscriptPrefix: String
    var isTechnical: Bool
    var vocabularyScope: UserVocabularyScope

    init(request: ContextualVocabularyRequest) {
        normalizedTranscriptPrefix = request.transcriptPrefix.normalizedSmartTermKey
        isTechnical = request.isTechnicalContext
        vocabularyScope = request.vocabularyScope
    }
}

private extension ContextualVocabularyRequest {
    var isTechnicalContext: Bool {
        guard scenario != .aiTool, scenario != .document, scenario != .note else { return true }
        let bundle = (frontmostAppBundleIdentifier ?? "").lowercased()
        return bundle.contains("cursor") ||
            bundle.contains("xcode") ||
            bundle.contains("terminal") ||
            bundle.contains("iterm") ||
            bundle.contains("obsidian") ||
            bundle.contains("codex") ||
            bundle.contains("todesktop")
    }
}

private extension SmartTerm {
    func isAllowed(for context: RankingContext) -> Bool {
        if scopes.contains(.all) {
            return true
        }

        if scopes.contains(context.vocabularyScope) {
            return true
        }

        return scopes.contains(.technical) && context.isTechnical
    }
}

private extension ContextualVocabularyRequest {
    var vocabularyScope: UserVocabularyScope {
        switch scenario {
        case .message:
            return .chat
        case .email:
            return .email
        case .document, .note:
            return .document
        case .aiTool:
            return .aiTool
        case .generic:
            return .all
        }
    }
}
