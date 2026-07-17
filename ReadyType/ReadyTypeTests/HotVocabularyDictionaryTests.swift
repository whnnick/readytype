import XCTest
@testable import ReadyType

final class HotVocabularyDictionaryTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testMergingPackFiltersExpiredTermsAndKeepsActiveTerms() {
        let verified = verifiedPack(terms: [
            HotVocabularyTerm(
                value: "流浪地球三",
                category: "movie",
                sourceID: "wikidata:Q1",
                weight: 80,
                expiresAt: now.addingTimeInterval(60)
            ),
            HotVocabularyTerm(
                value: "昨日热点",
                category: "other",
                sourceID: "wikidata:Q2",
                weight: 80,
                expiresAt: now.addingTimeInterval(-1)
            )
        ])

        let dictionary = SmartTermDictionary().mergingHotVocabulary(verified, now: now)

        XCTAssertEqual(dictionary.terms.map(\.value), ["流浪地球三"])
        XCTAssertEqual(dictionary.terms.first?.source, .trending)
    }

    func testUserVocabularyWinsWhenItMatchesTrendingTerm() {
        let verified = verifiedPack(terms: [
            HotVocabularyTerm(
                value: "ReadyType",
                aliases: ["Ready Type"],
                category: "product",
                sourceID: "wikidata:Q1",
                weight: 100
            )
        ])

        let dictionary = SmartTermDictionary()
            .mergingHotVocabulary(verified, now: now)
            .mergingUserVocabulary([UserVocabularyEntry(value: "ReadyType", kind: .product)])

        XCTAssertEqual(dictionary.terms.count, 1)
        XCTAssertEqual(dictionary.terms.first?.source, .userDefined)
        XCTAssertEqual(dictionary.terms.first?.allowsPostRecognitionCorrection, true)
    }

    func testTrendingAliasesDoNotTriggerPostRecognitionCorrection() {
        let verified = verifiedPack(terms: [
            HotVocabularyTerm(
                value: "流浪地球三",
                aliases: ["流浪地球 3"],
                category: "movie",
                sourceID: "wikidata:Q1",
                weight: 80
            )
        ])
        let dictionary = SmartTermDictionary().mergingHotVocabulary(verified, now: now)

        let suggestions = TermCorrectionService(dictionary: dictionary)
            .suggestions(for: "我想看流浪地球 3")

        XCTAssertEqual(suggestions, [])
    }

    private func verifiedPack(terms: [HotVocabularyTerm]) -> VerifiedHotVocabularyPack {
        let manifest = HotVocabularyManifest(
            schemaVersion: 1,
            packVersion: "2026.07.17",
            generatedAt: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(86_400),
            minimumAppVersion: "1.4.0",
            contentSHA256: String(repeating: "0", count: 64),
            signature: "test"
        )
        return VerifiedHotVocabularyPack(
            manifest: manifest,
            pack: HotVocabularyPack(packVersion: manifest.packVersion, terms: terms)
        )
    }
}
