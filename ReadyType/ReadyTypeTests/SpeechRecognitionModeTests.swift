import XCTest
@testable import ReadyType

final class SpeechRecognitionModeTests: XCTestCase {
    func testUserFacingModeNamesUsePlainLanguage() {
        XCTAssertEqual(SpeechRecognitionMode.allCases.map(\.displayName), [
            "自动选择",
            "极速识别",
            "高精度识别"
        ])
    }

    func testUserFacingModeDescriptionsExplainWhenToUseEachMode() {
        XCTAssertEqual(
            SpeechRecognitionMode.automatic.userDescription,
            "推荐默认使用。短句、聊天和搜索优先速度；长文、邮件、文档和术语较多时自动提高准确率。"
        )
        XCTAssertEqual(
            SpeechRecognitionMode.fastSystem.userDescription,
            "适合几句话以内的日常输入，响应最快。"
        )
        XCTAssertEqual(
            SpeechRecognitionMode.highAccuracyLocal.userDescription,
            "适合长文、邮件、文档、英文夹杂和专业词较多的内容。"
        )
    }

    func testUserFacingCopyDoesNotExposeEngineNames() {
        let bannedTerms = ["Apple Speech", "Whisper", "WhisperKit", "whisper.cpp"]
        let userFacingCopy = SpeechRecognitionMode.allCases.flatMap {
            [$0.displayName, $0.userDescription]
        }

        for copy in userFacingCopy {
            for bannedTerm in bannedTerms {
                XCTAssertFalse(
                    copy.localizedCaseInsensitiveContains(bannedTerm),
                    "User-facing recognition copy should not expose \(bannedTerm): \(copy)"
                )
            }
        }
    }

    func testModesHaveStableRawValuesForSettingsPersistence() {
        XCTAssertEqual(SpeechRecognitionMode.automatic.rawValue, "automatic")
        XCTAssertEqual(SpeechRecognitionMode.fastSystem.rawValue, "fastSystem")
        XCTAssertEqual(SpeechRecognitionMode.highAccuracyLocal.rawValue, "highAccuracyLocal")
    }
}
