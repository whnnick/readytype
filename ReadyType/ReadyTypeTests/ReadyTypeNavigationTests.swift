import XCTest
@testable import ReadyType

final class ReadyTypeNavigationTests: XCTestCase {
    func testPrimaryNavigationKeepsOnlyFrequentDestinations() {
        XCTAssertEqual(
            ReadyTypeSection.primarySections.map(\.title),
            ["首页", "使用概览", "常用词"]
        )
        XCTAssertEqual(ReadyTypeSection.allCases.map(\.title), ["首页", "使用概览", "常用词", "设置"])
    }

    func testSettingsCollectsLowFrequencyDestinations() {
        XCTAssertEqual(
            ReadyTypeSettingsSection.allCases.map(\.title),
            ["通用", "语音识别", "快捷键", "权限与隐私", "关于"]
        )
    }
}
