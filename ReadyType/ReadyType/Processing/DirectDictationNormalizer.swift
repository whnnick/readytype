import Foundation

struct DirectDictationNormalizationResult: Equatable {
    var normalizedText: String
    var appliedCorrections: [TermCorrectionSuggestion]

    var confidenceSummary: String {
        guard !appliedCorrections.isEmpty else {
            return "no local corrections"
        }

        let lowestConfidence = appliedCorrections.map(\.confidence).min() ?? 0
        return String(format: "%d local corrections, minimum confidence %.2f", appliedCorrections.count, lowestConfidence)
    }
}

struct DirectDictationNormalizer {
    private let termCorrectionService: TermCorrectionService
    private let minimumConfidence: Double

    init(dictionary: SmartTermDictionary, minimumConfidence: Double = 0.82) {
        self.termCorrectionService = TermCorrectionService(dictionary: dictionary)
        self.minimumConfidence = minimumConfidence
    }

    func normalize(_ text: String) -> DirectDictationNormalizationResult {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return DirectDictationNormalizationResult(normalizedText: trimmedText, appliedCorrections: [])
        }

        let corrections = highConfidenceSuggestions(for: trimmedText)
        var normalizedText = trimmedText
        var appliedCorrections: [TermCorrectionSuggestion] = []

        for correction in corrections {
            let replacementResult = replacingWholePhrase(
                correction.original,
                with: correction.replacement,
                in: normalizedText
            )

            guard replacementResult.didReplace else {
                continue
            }

            normalizedText = replacementResult.text
            appliedCorrections.append(correction)
        }

        normalizedText = SpokenTailNoiseCleaner.cleanDirectDictation(normalizedText)

        return DirectDictationNormalizationResult(
            normalizedText: normalizedText,
            appliedCorrections: appliedCorrections
        )
    }

    private func highConfidenceSuggestions(for text: String) -> [TermCorrectionSuggestion] {
        let staticSuggestions = Self.staticSuggestions(in: text)
        let dictionarySuggestions = termCorrectionService.suggestions(for: text)

        return (staticSuggestions + dictionarySuggestions)
            .filter { $0.confidence >= minimumConfidence }
            .filter { Self.isAllowedForDirectNormalization($0, in: text) }
            .sorted { lhs, rhs in
                if lhs.original.count == rhs.original.count {
                    return lhs.confidence > rhs.confidence
                }
                return lhs.original.count > rhs.original.count
            }
    }

    private static func staticSuggestions(in text: String) -> [TermCorrectionSuggestion] {
        var suggestions = [
            TermCorrectionSuggestion(original: "get hot actions", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "get hot action", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "get hub actions", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "get hub action", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepHub Actions", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepHub Action", replacement: "GitHub Actions", confidence: 0.9),
            TermCorrectionSuggestion(original: "github actions", replacement: "GitHub Actions", confidence: 0.88),
            TermCorrectionSuggestion(original: "github action", replacement: "GitHub Actions", confidence: 0.88),
            TermCorrectionSuggestion(original: "更新日誌", replacement: "更新日志", confidence: 0.9),
            TermCorrectionSuggestion(original: "更新误诸", replacement: "更新日志", confidence: 0.9),
            TermCorrectionSuggestion(original: "更新日课", replacement: "更新日志", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSig的Page", replacement: "DeepSeek的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSeek的Page", replacement: "DeepSeek的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSig 的 Page", replacement: "DeepSeek 的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSeek 的 Page", replacement: "DeepSeek 的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSig的页面", replacement: "DeepSeek的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSeek的页面", replacement: "DeepSeek的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSig 的页面", replacement: "DeepSeek 的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "DeepSeek 的页面", replacement: "DeepSeek 的配置", confidence: 0.9),
            TermCorrectionSuggestion(original: "docker compass复数read", replacement: "Docker Compose部署Redis", confidence: 0.9),
            TermCorrectionSuggestion(original: "docker compose复数read", replacement: "Docker Compose部署Redis", confidence: 0.9)
        ]

        if hasTechnicalReleaseChecklistContext(text) {
            suggestions.append(contentsOf: [
                TermCorrectionSuggestion(original: "Reddit Tab", replacement: "ReadyType", confidence: 0.88),
                TermCorrectionSuggestion(original: "DeepSeek page", replacement: "DeepSeek的配置", confidence: 0.9),
                TermCorrectionSuggestion(original: "DeepSeek Page", replacement: "DeepSeek的配置", confidence: 0.9),
                TermCorrectionSuggestion(original: "DeepSig page", replacement: "DeepSeek的配置", confidence: 0.9),
                TermCorrectionSuggestion(original: "DeepSig Page", replacement: "DeepSeek的配置", confidence: 0.9)
            ])
        }

        if hasReadmeContext(text) || hasTechnicalReadmeChecklistContext(text) {
            suggestions.append(contentsOf: [
                TermCorrectionSuggestion(original: "read me", replacement: "README", confidence: 0.84),
                TermCorrectionSuggestion(original: "readme", replacement: "README", confidence: 0.86),
                TermCorrectionSuggestion(original: "ReadMe", replacement: "README", confidence: 0.86),
                TermCorrectionSuggestion(original: "Redmi", replacement: "README", confidence: 0.84)
            ])
        }

        return suggestions.filter { suggestion in
            text.range(of: suggestion.original, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private static func hasReadmeContext(_ text: String) -> Bool {
        [
            "read me 文档",
            "read me 文件",
            "read me 说明",
            "readme 文档",
            "readme 文件",
            "readme 说明",
            "readme更新日志",
            "readme更新日誌",
            "read me更新日志",
            "read me更新日誌",
            "redmi 文档",
            "redmi 文件",
            "redmi 说明",
            "redmi文档",
            "redmi文件",
            "redmi说明",
            "redmi更新日志",
            "redmi更新日誌",
            "更新 read me",
            "更新 readme",
            "更新 redmi",
            "更新readme",
            "更新redmi",
            "修改 read me",
            "修改 readme",
            "修改 redmi",
            "修改readme",
            "修改redmi",
            "打开 read me",
            "打开 readme",
            "打开 redmi",
            "打开readme",
            "打开redmi",
            "同步 read me",
            "同步 readme",
            "同步 redmi",
            "同步readme",
            "同步redmi",
            "项目 read me",
            "项目 readme",
            "项目 redmi",
            "项目readme",
            "项目redmi",
            "仓库 read me",
            "仓库 readme",
            "仓库 redmi",
            "仓库readme",
            "仓库redmi",
            "repo read me",
            "repo readme",
            "repo redmi",
            "repository read me",
            "repository readme",
            "repository redmi"
        ].contains { keyword in
            text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private static func hasTechnicalReadmeChecklistContext(_ text: String) -> Bool {
        let hasReadmeLikeToken = text.range(of: "Redmi", options: [.caseInsensitive, .diacriticInsensitive]) != nil
        guard hasReadmeLikeToken else {
            return false
        }

        let technicalSignals = [
            "GitHub Actions",
            "Docker Compose",
            "Redis",
            "Nextcloud",
            "NextCloud",
            "DeepSeek",
            "DeepSig",
            "打包文件",
            "更新日志",
            "更新误诸"
        ]

        return technicalSignals.contains { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

    private static func hasTechnicalReleaseChecklistContext(_ text: String) -> Bool {
        let technicalSignals = [
            "GitHub Actions",
            "README",
            "Docker Compose",
            "Redis",
            "Nextcloud",
            "NextCloud",
            "DeepSeek",
            "DeepSig",
            "打包文件",
            "更新日志"
        ]

        let signalCount = technicalSignals.filter { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }.count

        let checklistSignals = ["检查", "确认", "打包文件", "更新日志"]
        let hasChecklistSignal = checklistSignals.contains { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        return signalCount >= 4 && hasChecklistSignal
    }

    private static func isAllowedForDirectNormalization(
        _ suggestion: TermCorrectionSuggestion,
        in text: String
    ) -> Bool {
        if suggestion.scopes.contains(.all) {
            return true
        }

        if suggestion.scopes.contains(.technical) {
            return hasDirectTechnicalContext(text)
        }

        return false
    }

    private static func hasDirectTechnicalContext(_ text: String) -> Bool {
        if hasTechnicalReleaseChecklistContext(text) ||
            hasTechnicalReadmeChecklistContext(text) ||
            hasReadmeContext(text) {
            return true
        }

        let technicalSignals = [
            "GitHub Actions",
            "README",
            "Docker Compose",
            "Redis",
            "Nextcloud",
            "NextCloud",
            "DeepSeek",
            "DeepSig",
            "API",
            "Xcode",
            "Cursor",
            "更新日志",
            "语音包",
            "高精度语音包",
            "极速识别"
        ]
        let signalCount = technicalSignals.filter { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }.count

        let actionSignals = ["检查", "更新", "同步", "修复", "发布", "配置", "构建", "提交"]
        let hasActionSignal = actionSignals.contains { signal in
            text.range(of: signal, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }

        return signalCount >= 1 && hasActionSignal
    }

    private func replacingWholePhrase(
        _ phrase: String,
        with replacement: String,
        in text: String
    ) -> (text: String, didReplace: Bool) {
        let escapedPhrase = NSRegularExpression.escapedPattern(for: phrase)
        let pattern = if phrase.containsChineseScalar {
            phrase.containsLatinScalar ? #"(?i)"# + escapedPhrase : escapedPhrase
        } else {
            #"(?i)(?<![A-Za-z0-9])"# + escapedPhrase + #"(?![A-Za-z0-9])"#
        }
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, false)
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let replaced = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: replacement
        )

        return (replaced, replaced != text)
    }
}

private extension String {
    var containsChineseScalar: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    var containsLatinScalar: Bool {
        unicodeScalars.contains { scalar in
            (0x0041...0x005A).contains(Int(scalar.value)) ||
                (0x0061...0x007A).contains(Int(scalar.value))
        }
    }
}
