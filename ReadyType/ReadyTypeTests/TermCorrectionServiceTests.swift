import XCTest
@testable import ReadyType

final class TermCorrectionServiceTests: XCTestCase {
    func testCorrectionServiceRestoresCanonicalCapitalizationForUserTerms() {
        let dictionary = SmartTermDictionary(terms: [
            SmartTerm(value: "Reddit", source: .userDefined, weight: 100)
        ])

        let suggestions = TermCorrectionService(dictionary: dictionary)
            .suggestions(for: "我也会看reddit")

        XCTAssertTrue(
            suggestions.contains(
                TermCorrectionSuggestion(
                    original: "reddit",
                    replacement: "Reddit",
                    confidence: 0.98,
                    source: .userDefined
                )
            )
        )
    }

    func testCorrectionServiceSuggestsLikelyTechnicalTermWithoutReplacingText() {
        let service = TermCorrectionService(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "Redis", source: .packageName, weight: 10)
            ])
        )

        let suggestions = service.suggestions(for: "瑞迪斯 缓存")

        XCTAssertEqual(suggestions, [
            TermCorrectionSuggestion(original: "瑞迪斯", replacement: "Redis", confidence: 0.9)
        ])
    }

    func testCorrectionServiceUsesDictionaryAliasesCaseInsensitively() {
        let service = TermCorrectionService(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "GitHub", source: .builtIn, weight: 10, aliases: ["get up"])
            ])
        )

        let suggestions = service.suggestions(for: "请同步到 Get Up")

        XCTAssertEqual(suggestions, [
            TermCorrectionSuggestion(original: "get up", replacement: "GitHub", confidence: 0.82)
        ])
    }

    func testCorrectionServiceDoesNotSuggestAliasInsideCanonicalLatinTerm() {
        let service = TermCorrectionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(for: "请检查 GitHub Actions 更新日志")

        XCTAssertFalse(suggestions.contains {
            $0.original == "github action" && $0.replacement == "GitHub Actions"
        })
    }

    func testCorrectionServiceUsesUserVocabularyAliases() {
        let dictionary = SmartTermDictionary.readyTypeDefault.mergingUserVocabulary([
            UserVocabularyEntry(value: "ReadyWOD", kind: .project, aliases: ["ready wod"])
        ])
        let service = TermCorrectionService(dictionary: dictionary)

        let suggestions = service.suggestions(for: "今天整理 ready wod 的训练计划")

        XCTAssertEqual(suggestions.first?.original, "ready wod")
        XCTAssertEqual(suggestions.first?.replacement, "ReadyWOD")
    }

    func testCorrectionServiceKeepsNarrowScopeForDuplicateAliases() throws {
        let dictionary = SmartTermDictionary.readyTypeDefault.mergingUserVocabulary([
            UserVocabularyEntry(
                value: "ReadyType",
                kind: .product,
                aliases: ["Reddit Tab"],
                scopes: [.technical],
                source: .confirmedSuggestion,
                confidence: 0.88,
                confirmedCount: 2
            )
        ])
        let service = TermCorrectionService(dictionary: dictionary)

        let suggestion = try XCTUnwrap(service.suggestions(for: "今天打开 Reddit Tab 看一个帖子").first {
            $0.original == "Reddit Tab" && $0.replacement == "ReadyType"
        })

        XCTAssertEqual(suggestion.scopes, [.technical])
    }

    func testCorrectionServiceSuggestsAcceptanceConfusablesAsCandidates() {
        let service = TermCorrectionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(
            for: "计划用 Docker Compose 部署 Reddit 和 NextCloud，把 DeepSeq 和 DeepSig 的结果写到 ReadyTap 文档里，再同步 Redis Type 文档，并检查报表单、高精度银包、急速识别、代办事项、大消息、更新误诸、复册、禁音词和全线说明。"
        )

        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "Reddit", replacement: "Redis", confidence: 0.78)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "NextCloud", replacement: "Nextcloud", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "DeepSeq", replacement: "DeepSeek", confidence: 0.86)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "DeepSig", replacement: "DeepSeek", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "ReadyTap", replacement: "ReadyType", confidence: 0.88)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "Redis Type", replacement: "ReadyType", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "报表单", replacement: "报价单", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "高精度银包", replacement: "高精度语音包", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "急速识别", replacement: "极速识别", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "代办事项", replacement: "待办事项", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "大消息", replacement: "大小写", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "更新误诸", replacement: "更新日志", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "复册", replacement: "复测", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "禁音词", replacement: "近音词", confidence: 0.82)))
        XCTAssertTrue(suggestions.contains(TermCorrectionSuggestion(original: "全线说明", replacement: "权限说明", confidence: 0.82)))
    }

    func testCorrectionServiceDoesNotAggressivelyCorrectShortCommonWords() {
        let service = TermCorrectionService(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "AI", source: .builtIn, weight: 10),
                SmartTerm(value: "API", source: .builtIn, weight: 10)
            ])
        )

        XCTAssertEqual(service.suggestions(for: "爱 一个接口"), [])
    }
}
