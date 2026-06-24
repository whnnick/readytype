import XCTest
@testable import ReadyType

final class DirectDictationNormalizerTests: XCTestCase {
    func testNormalizesHighConfidenceTechnicalPhrases() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("请更新 Redmi 文档，并检查 get hot action 是否通过，高精度银包和急速识别也要写对")

        XCTAssertEqual(result.normalizedText, "请更新 README 文档，并检查 GitHub Actions 是否通过，高精度语音包和极速识别也要写对")
        XCTAssertEqual(Set(result.appliedCorrections.map(\.replacement)), Set(["GitHub Actions", "README", "高精度语音包", "极速识别"]))
    }

    func testNormalizesReleaseChecklistTermsWithoutWordSpacing() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("检查GitHub Actions Readme更新日誌和打包文件")

        XCTAssertEqual(result.normalizedText, "检查GitHub Actions README更新日志和打包文件")
        XCTAssertEqual(Set(result.appliedCorrections.map(\.replacement)), Set(["README", "更新日志"]))
    }

    func testNormalizesReleaseAcceptanceNearHomophones() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("下午复册微信粘贴流程，修复禁音词和尽因此保护，并检查全线说明。")

        XCTAssertEqual(result.normalizedText, "下午复测微信粘贴流程，修复近音词和近音词保护，并检查权限说明。")
        XCTAssertEqual(Set(result.appliedCorrections.map(\.replacement)), Set(["复测", "近音词", "权限说明"]))
    }

    func testNormalizesReadmeWhenSpokenAsSeparateWordsBeforeUpdateLog() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("提醒我检查get hot action read me更新日志和打包文件")

        XCTAssertEqual(result.normalizedText, "提醒我检查GitHub Actions README更新日志和打包文件")
        XCTAssertEqual(Set(result.appliedCorrections.map(\.replacement)), Set(["GitHub Actions", "README"]))
    }

    func testNormalizesDockerRedisNextcloudDeploymentFallback() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("我想用docker Compass复数read和next cloud")

        XCTAssertEqual(result.normalizedText, "我想用Docker Compose部署Redis和Nextcloud")
        XCTAssertEqual(Set(result.appliedCorrections.map(\.replacement)), Set(["Docker Compose部署Redis", "Nextcloud"]))
    }

    func testUsesUserVocabularyAliasesWithoutCallingAI() {
        let dictionary = SmartTermDictionary.readyTypeDefault.mergingUserVocabulary([
            UserVocabularyEntry(value: "ReadyWOD", kind: .project, aliases: ["ready wod"])
        ])
        let normalizer = DirectDictationNormalizer(dictionary: dictionary)

        let result = normalizer.normalize("把 ready wod 今天的训练计划发给教练")

        XCTAssertEqual(result.normalizedText, "把 ReadyWOD 今天的训练计划发给教练")
        XCTAssertEqual(result.appliedCorrections, [
            TermCorrectionSuggestion(original: "ready wod", replacement: "ReadyWOD", confidence: 0.82)
        ])
    }

    func testConfirmedTechnicalVocabularyAliasesRespectLocalContext() {
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
        let normalizer = DirectDictationNormalizer(dictionary: dictionary)

        let technicalResult = normalizer.normalize("检查 Reddit Tab 的更新日志和 GitHub Actions")
        let chatResult = normalizer.normalize("今天打开 Reddit Tab 看一个帖子")

        XCTAssertEqual(technicalResult.normalizedText, "检查 ReadyType 的更新日志和 GitHub Actions")
        XCTAssertTrue(technicalResult.appliedCorrections.contains {
            $0.original == "Reddit Tab" && $0.replacement == "ReadyType"
        })
        XCTAssertEqual(chatResult.normalizedText, "今天打开 Reddit Tab 看一个帖子")
        XCTAssertFalse(chatResult.appliedCorrections.contains {
            $0.original == "Reddit Tab" && $0.replacement == "ReadyType"
        })
    }

    func testDoesNotApplyLowConfidenceAmbiguousCandidates() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("今天在 Reddit 看到了一个帖子")

        XCTAssertEqual(result.normalizedText, "今天在 Reddit 看到了一个帖子")
        XCTAssertEqual(result.appliedCorrections, [])
    }

    func testDoesNotRewriteRedditTabOutsideTechnicalChecklistContext() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("今天打开 Reddit Tab 看一个帖子")

        XCTAssertEqual(result.normalizedText, "今天打开 Reddit Tab 看一个帖子")
        XCTAssertEqual(result.appliedCorrections, [])
    }

    func testDoesNotRewriteReadMeOutsideTechnicalContext() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("please read me the message")

        XCTAssertEqual(result.normalizedText, "please read me the message")
        XCTAssertEqual(result.appliedCorrections, [])
    }

    func testDoesNotRewriteRedmiOutsideReadmeContext() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("我在看 Redmi 手机")

        XCTAssertEqual(result.normalizedText, "我在看 Redmi 手机")
        XCTAssertEqual(result.appliedCorrections, [])
    }

    func testRemovesConservativeTrailingSpokenNoise() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        let result = normalizer.normalize("今天先不要继续加新功能先复测微信粘贴流程检查近音词保护和权限说明好谢谢大家")

        XCTAssertEqual(result.normalizedText, "今天先不要继续加新功能先复测微信粘贴流程检查近音词保护和权限说明")
    }

    func testDoesNotRemoveMeaningfulTrailingGood() {
        let normalizer = DirectDictationNormalizer(dictionary: .readyTypeDefault)

        XCTAssertEqual(normalizer.normalize("这个识别效果很好").normalizedText, "这个识别效果很好")
        XCTAssertEqual(normalizer.normalize("高精度语音包已经准备好").normalizedText, "高精度语音包已经准备好")
        XCTAssertEqual(normalizer.normalize("这段说明好").normalizedText, "这段说明好")
        XCTAssertEqual(normalizer.normalize("今天谢谢大家的帮忙").normalizedText, "今天谢谢大家的帮忙")
    }
}
