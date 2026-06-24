import XCTest
@testable import ReadyType

final class UserVocabularyLearningServiceTests: XCTestCase {
    func testSuggestsTechnicalAliasWhenContextSupportsCorrection() {
        let service = UserVocabularyLearningService()

        let suggestions = service.suggestions(
            transcript: "Reddit Tab现在需要检查GitHub Actions、README、Docker Compose、Redis、Nextcloud、DeepSeek page，确认打包文件和更新日志都没有问题。",
            finalText: "ReadyType现在需要检查GitHub Actions、README、Docker Compose、Redis、Nextcloud、DeepSeek的配置，确认打包文件和更新日志都没有问题。",
            scenario: .document,
            existingEntries: [],
            correctionCandidates: [
                TermCorrectionSuggestion(original: "Reddit Tab", replacement: "ReadyType", confidence: 0.88)
            ]
        )

        XCTAssertEqual(suggestions, [
            UserVocabularyLearningSuggestion(
                value: "ReadyType",
                alias: "Reddit Tab",
                kind: .technical,
                scopes: [.technical],
                reason: "以后按这个写法处理",
                confidence: 0.88
            )
        ])
    }

    func testDoesNotSuggestOrdinaryEnglishAliasOutsideSupportedContext() {
        let service = UserVocabularyLearningService()

        let suggestions = service.suggestions(
            transcript: "今天打开 Reddit Tab 看一个帖子",
            finalText: "今天打开 Reddit Tab 看一个帖子",
            scenario: .generic,
            existingEntries: [],
            correctionCandidates: [
                TermCorrectionSuggestion(original: "Reddit Tab", replacement: "ReadyType", confidence: 0.88)
            ]
        )

        XCTAssertEqual(suggestions, [])
    }

    func testDoesNotSuggestSavedOrIgnoredAliasesAgain() {
        let service = UserVocabularyLearningService()
        let savedEntry = UserVocabularyEntry(
            value: "ReadyType",
            kind: .product,
            aliases: ["Ready Tap"],
            ignoredAliases: ["Reddit Tab"]
        )

        let suggestions = service.suggestions(
            transcript: "Reddit Tab现在需要检查GitHub Actions、README和DeepSeek。",
            finalText: "ReadyType现在需要检查GitHub Actions、README和DeepSeek。",
            scenario: .document,
            existingEntries: [savedEntry],
            correctionCandidates: [
                TermCorrectionSuggestion(original: "Ready Tap", replacement: "ReadyType", confidence: 0.88),
                TermCorrectionSuggestion(original: "Reddit Tab", replacement: "ReadyType", confidence: 0.9)
            ]
        )

        XCTAssertEqual(suggestions, [])
    }
}
