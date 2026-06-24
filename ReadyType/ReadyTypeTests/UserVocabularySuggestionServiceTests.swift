import XCTest
@testable import ReadyType

final class UserVocabularySuggestionServiceTests: XCTestCase {
    func testSuggestsConfirmedTermCandidatesFromCurrentTranscript() {
        let service = UserVocabularySuggestionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(
            transcript: "请把 ReadyTap 的配置文档整理一下",
            finalText: "请把 ReadyType 的配置文档整理一下",
            scenario: .document,
            existingEntries: []
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.value, "ReadyType")
        XCTAssertEqual(suggestions.first?.kind, .technical)
        XCTAssertEqual(suggestions.first?.aliases, ["ReadyTap"])
        XCTAssertEqual(suggestions.first?.scopes, [.technical])
        XCTAssertEqual(suggestions.first?.confidence, 0.88)
        XCTAssertEqual(suggestions.first?.reason, "以后按这个写法处理")
    }

    func testSuggestsAliasesForExistingTermsWhenAliasIsNotSaved() {
        let service = UserVocabularySuggestionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(
            transcript: "请把 ReadyTap 的配置文档整理一下",
            finalText: "请把 ReadyType 的配置文档整理一下",
            scenario: .document,
            existingEntries: [
                UserVocabularyEntry(value: "ReadyType", kind: .product)
            ]
        )

        XCTAssertEqual(suggestions.first?.value, "ReadyType")
        XCTAssertEqual(suggestions.first?.aliases, ["ReadyTap"])
    }

    func testDoesNotSuggestSavedOrIgnoredAliases() {
        let service = UserVocabularySuggestionService(dictionary: .readyTypeDefault)

        let savedSuggestions = service.suggestions(
            transcript: "请把 ReadyTap 的配置文档整理一下",
            finalText: "请把 ReadyType 的配置文档整理一下",
            scenario: .document,
            existingEntries: [
                UserVocabularyEntry(value: "ReadyType", kind: .product, aliases: ["ReadyTap"])
            ]
        )
        let ignoredSuggestions = service.suggestions(
            transcript: "请把 ReadyTap 的配置文档整理一下",
            finalText: "请把 ReadyType 的配置文档整理一下",
            scenario: .document,
            existingEntries: [
                UserVocabularyEntry(value: "ReadyType", kind: .product, ignoredAliases: ["ReadyTap"])
            ]
        )

        XCTAssertEqual(savedSuggestions, [])
        XCTAssertEqual(ignoredSuggestions, [])
    }

    func testDoesNotSuggestSiblingAliasesAfterOneAliasIsSaved() {
        let existingEntries = [
            UserVocabularyEntry(value: "ReadyType", kind: .technical, aliases: ["Reddit Tab"])
        ]
        let service = UserVocabularySuggestionService(
            dictionary: SmartTermDictionary.readyTypeDefault.mergingUserVocabulary(existingEntries)
        )

        let suggestions = service.suggestions(
            transcript: "请检查 Reddit Type 的 README 和 GitHub Actions 更新日志",
            finalText: "请检查 ReadyType 的 README 和 GitHub Actions 更新日志",
            scenario: .document,
            existingEntries: existingEntries
        )

        XCTAssertFalse(suggestions.contains { suggestion in
            suggestion.value == "ReadyType" && suggestion.aliases.contains("Reddit Type")
        })
    }

    func testDoesNotSuggestOrdinaryEnglishAliasesInChat() {
        let service = UserVocabularySuggestionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(
            transcript: "今天打开 Reddit Tab 看帖子",
            finalText: "今天打开 ReadyType 看帖子",
            scenario: .message,
            existingEntries: []
        )

        XCTAssertEqual(suggestions, [])
    }

    func testSuggestsTechnicalLearningAliasWhenFinalTextContainsKnownTerm() {
        let service = UserVocabularySuggestionService(dictionary: .readyTypeDefault)

        let suggestions = service.suggestions(
            transcript: "请检查 Reddit Tab 的 README 和 GitHub Actions 更新日志",
            finalText: "请检查 ReadyType 的 README 和 GitHub Actions 更新日志",
            scenario: .document,
            existingEntries: []
        )

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.value, "ReadyType")
        XCTAssertEqual(suggestions.first?.aliases, ["Reddit Tab"])
        XCTAssertEqual(suggestions.first?.scopes, [.technical])
        XCTAssertEqual(suggestions.first?.confidence, 0.88)
    }
}
