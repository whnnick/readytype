import XCTest
@testable import ReadyType

final class OutputModeTests: XCTestCase {
    func testUserFacingModeNamesUsePlainLanguage() {
        XCTAssertEqual(OutputMode.allCases.map(\.displayName), [
            "直接转文字",
            "整理成文",
            "翻译成英文",
            "写给 AI"
        ])
    }

    func testUserFacingModeDescriptionsExplainBehavior() {
        XCTAssertTrue(OutputMode.dictation.userDescription.contains("基本按你说的转成文字"))
        XCTAssertTrue(OutputMode.aiCleanup.userDescription.contains("口语整理成可以直接发送或保存的文本"))
        XCTAssertTrue(OutputMode.translationToEnglish.userDescription.contains("输出成自然英文"))
        XCTAssertTrue(OutputMode.promptOutput.userDescription.contains("任务说明"))
    }

    func testModeRequiresAIOnlyWhenTextProcessingIsNeeded() {
        XCTAssertFalse(OutputMode.dictation.requiresAI)
        XCTAssertTrue(OutputMode.aiCleanup.requiresAI)
        XCTAssertTrue(OutputMode.translationToEnglish.requiresAI)
        XCTAssertTrue(OutputMode.promptOutput.requiresAI)
    }
}
