import XCTest
@testable import ReadyType

final class ContextualVocabularyProviderTests: XCTestCase {
    func testCursorContextPrioritizesTechnicalTerms() async {
        let provider = ContextualVocabularyProvider(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "Docker", source: .builtIn, weight: 8),
                SmartTerm(value: "Redis", source: .packageName, weight: 7),
                SmartTerm(value: "meeting", source: .builtIn, weight: 2)
            ])
        )

        let terms = await provider.terms(
            for: ContextualVocabularyRequest(
                scenario: .aiTool,
                frontmostAppBundleIdentifier: "com.todesktop.230313mzl4w4u92",
                projectRoot: nil,
                transcriptPrefix: "帮我写一个 docker compose",
                maximumTerms: 3,
                timeoutMilliseconds: 80
            )
        )

        XCTAssertEqual(terms.prefix(2), ["Docker", "Redis"])
    }

    func testChatScenarioReturnsSmallCandidateSet() async {
        let provider = ContextualVocabularyProvider(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "Docker", source: .builtIn, weight: 8),
                SmartTerm(value: "Redis", source: .packageName, weight: 7),
                SmartTerm(value: "Kubernetes", source: .builtIn, weight: 8),
                SmartTerm(value: "API", source: .builtIn, weight: 6)
            ])
        )

        let terms = await provider.terms(
            for: ContextualVocabularyRequest(
                scenario: .message,
                frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                projectRoot: nil,
                transcriptPrefix: "",
                maximumTerms: 60,
                timeoutMilliseconds: 80
            )
        )

        XCTAssertLessThanOrEqual(terms.count, 2)
    }

    func testUserDefinedTermsRankBeforeBuiltInTerms() async {
        let provider = ContextualVocabularyProvider(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "ReadyPlay", source: .userDefined, weight: 1),
                SmartTerm(value: "Docker", source: .builtIn, weight: 10)
            ])
        )

        let terms = await provider.terms(
            for: ContextualVocabularyRequest(
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                projectRoot: nil,
                transcriptPrefix: "ready play 的方案",
                maximumTerms: 2,
                timeoutMilliseconds: 80
            )
        )

        XCTAssertEqual(terms.first, "ReadyPlay")
    }

    func testUserVocabularyEntriesFeedImmediateSpeechContext() {
        let dictionary = SmartTermDictionary.readyTypeDefault.mergingUserVocabulary([
            UserVocabularyEntry(value: "王小明", kind: .person),
            UserVocabularyEntry(value: "ReadyWOD", kind: .project, aliases: ["ready wod"])
        ])
        let provider = ContextualVocabularyProvider(dictionary: dictionary)

        let terms = provider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: .message,
                frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                projectRoot: nil,
                transcriptPrefix: "跟王小明说 ready wod 明天发布",
                maximumTerms: 6,
                timeoutMilliseconds: 80
            )
        )

        XCTAssertEqual(Set(terms), Set(["ReadyWOD", "王小明"]))
        XCTAssertEqual(terms.count, 2)
    }

    func testConfirmedTechnicalVocabularyIsScopedOutOfChatContext() {
        let dictionary = SmartTermDictionary(terms: [
            SmartTerm(value: "王小明", source: .userDefined, weight: 130)
        ]).mergingUserVocabulary([
            UserVocabularyEntry(
                value: "ReadyType",
                kind: .product,
                aliases: ["Reddit Tab"],
                scopes: [.technical],
                source: .confirmedSuggestion,
                confidence: 0.88,
                confirmedCount: 3
            )
        ])
        let provider = ContextualVocabularyProvider(dictionary: dictionary)

        let chatTerms = provider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: .message,
                frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                transcriptPrefix: "今天看 Reddit Tab",
                maximumTerms: 6
            )
        )
        let documentTerms = provider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: .document,
                frontmostAppBundleIdentifier: "com.apple.TextEdit",
                transcriptPrefix: "检查 Reddit Tab 的更新日志",
                maximumTerms: 6
            )
        )

        XCTAssertFalse(chatTerms.contains("ReadyType"))
        XCTAssertTrue(documentTerms.contains("ReadyType"))
    }

    func testDefaultDictionaryIncludesReleaseAcceptanceTechnicalTerms() {
        let values = Set(SmartTermDictionary.readyTypeDefault.terms.map(\.value))

        XCTAssertTrue(values.contains("ReadyType"))
        XCTAssertTrue(values.contains("GitHub"))
        XCTAssertTrue(values.contains("Docker Compose"))
        XCTAssertTrue(values.contains("Kubernetes"))
        XCTAssertTrue(values.contains("Redis"))
        XCTAssertTrue(values.contains("Nextcloud"))
    }

    func testImmediateTermsCanFeedSpeechRecognitionContext() {
        let provider = ContextualVocabularyProvider(dictionary: .readyTypeDefault)

        let terms = provider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: .generic,
                frontmostAppBundleIdentifier: "com.apple.TextEdit",
                projectRoot: nil,
                transcriptPrefix: "",
                maximumTerms: 80,
                timeoutMilliseconds: 80
            )
        )

        XCTAssertTrue(terms.contains("ReadyType"))
        XCTAssertTrue(terms.contains("GitHub"))
        XCTAssertTrue(terms.contains("Kubernetes"))
        XCTAssertTrue(terms.contains("Redis"))
    }

    func testTimeoutReturnsEmptyCandidates() async {
        let provider = ContextualVocabularyProvider(
            dictionary: SmartTermDictionary(terms: [
                SmartTerm(value: "Docker", source: .builtIn, weight: 8)
            ]),
            artificialDelayNanoseconds: 5_000_000
        )

        let terms = await provider.terms(
            for: ContextualVocabularyRequest(
                scenario: .document,
                frontmostAppBundleIdentifier: nil,
                projectRoot: nil,
                transcriptPrefix: "docker",
                maximumTerms: 10,
                timeoutMilliseconds: 1
            )
        )

        XCTAssertEqual(terms, [])
    }

    func testTrendingTermsAreCappedAtTwentyAndRankBelowBuiltInTerms() {
        let trendingTerms = (0..<40).map { index in
            SmartTerm(value: "Trending\(index)", source: .trending, weight: 100)
        }
        let provider = ContextualVocabularyProvider(
            dictionary: SmartTermDictionary(
                terms: [SmartTerm(value: "BuiltIn", source: .builtIn, weight: 1)] + trendingTerms
            )
        )

        let terms = provider.termsImmediately(
            for: ContextualVocabularyRequest(
                scenario: .generic,
                transcriptPrefix: "",
                maximumTerms: 100
            )
        )

        XCTAssertEqual(terms.first, "BuiltIn")
        XCTAssertEqual(terms.filter { $0.hasPrefix("Trending") }.count, 20)
        XCTAssertEqual(terms.count, 21)
    }
}
