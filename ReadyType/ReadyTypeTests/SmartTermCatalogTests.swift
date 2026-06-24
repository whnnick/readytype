import XCTest
@testable import ReadyType

final class SmartTermCatalogTests: XCTestCase {
    func testDefaultCatalogSeparatesProductTechnicalAndWorkPhraseTerms() {
        let productValues = Set(SmartTermCatalog.productTerms.map(\.value))
        let technicalValues = Set(SmartTermCatalog.technicalTerms.map(\.value))
        let workPhraseValues = Set(SmartTermCatalog.workPhraseTerms.map(\.value))

        XCTAssertTrue(productValues.isSuperset(of: ["ReadyType", "高精度语音包", "极速识别", "Option", "Esc"]))
        XCTAssertTrue(technicalValues.isSuperset(of: ["README", "GitHub Actions", "Redis", "Docker Compose"]))
        XCTAssertTrue(workPhraseValues.isSuperset(of: ["待办事项", "大小写", "报价单", "灰度发布"]))
    }

    func testDefaultDictionaryUsesCatalogTerms() {
        let catalogValues = Set(SmartTermCatalog.defaultTerms.map(\.value))
        let dictionaryValues = Set(SmartTermDictionary.readyTypeDefault.terms.map(\.value))

        XCTAssertEqual(dictionaryValues, catalogValues)
    }

    func testMergingUserVocabularyPreservesBuiltInAliases() throws {
        let dictionary = SmartTermDictionary.readyTypeDefault.mergingUserVocabulary([
            UserVocabularyEntry(value: "ReadyType", kind: .technical, aliases: ["Reddit Tab"])
        ])

        let readyTypeTerm = try XCTUnwrap(dictionary.terms.first { $0.value == "ReadyType" })

        XCTAssertTrue(readyTypeTerm.aliases.contains("Reddit Tab"))
        XCTAssertTrue(readyTypeTerm.aliases.contains("Reddit Type"))
    }
}
