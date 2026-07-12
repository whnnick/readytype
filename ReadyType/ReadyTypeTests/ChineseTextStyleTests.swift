import XCTest
@testable import ReadyType

final class ChineseTextStyleTests: XCTestCase {
    func testSimplifiedStyleConvertsTraditionalChinese() {
        XCTAssertEqual(
            ChineseTextConverter.convert("開始動工吧，準備軟體更新。", style: .simplified),
            "开始动工吧，准备软体更新。"
        )
    }

    func testChineseAndMixedTextUseFullWidthPunctuation() {
        XCTAssertEqual(
            LanguageAwarePunctuationNormalizer.normalize("我用 Typeless,也用 Reddit.可以吗?"),
            "我用 Typeless，也用 Reddit。可以吗？"
        )
    }

    func testFullyEnglishTextUsesASCIIPunctuation() {
        XCTAssertEqual(
            LanguageAwarePunctuationNormalizer.normalize("I use Typeless，Reddit，and ReadyType。Does it work？"),
            "I use Typeless,Reddit,and ReadyType.Does it work?"
        )
    }

    func testChineseTextPreservesVersionsURLsTimesAndNumbers() {
        XCTAssertEqual(
            LanguageAwarePunctuationNormalizer.normalize("ReadyType 1.2.0,访问 https://readytype.app,时间 3:30,费用 1,000.50 元."),
            "ReadyType 1.2.0，访问 https://readytype.app，时间 3:30，费用 1,000.50 元。"
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
