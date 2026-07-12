import XCTest
@testable import ReadyType

final class ChineseTextStyleTests: XCTestCase {
    func testSimplifiedStyleConvertsTraditionalChinese() {
        XCTAssertEqual(
            ChineseTextConverter.convert("開始動工吧，準備軟體更新。", style: .simplified),
            "开始动工吧，准备软体更新。"
        )
    }

    func testTraditionalStyleConvertsSimplifiedChinese() {
        XCTAssertEqual(
            ChineseTextConverter.convert("开始动工吧，准备软件更新。", style: .traditional),
            "開始動工吧，準備軟件更新。"
        )
    }

    func testConversionPreservesEnglishAndNumbers() {
        XCTAssertEqual(
            ChineseTextConverter.convert("ReadyType 1.2.0 開始測試", style: .simplified),
            "ReadyType 1.2.0 开始测试"
        )
    }
}
