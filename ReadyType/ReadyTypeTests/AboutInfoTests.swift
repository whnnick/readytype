import XCTest
@testable import ReadyType

final class AboutInfoTests: XCTestCase {
    func testVersionDisplayShowsShortVersionWithoutBuildNumber() {
        let info = ReadyTypeAboutInfo(
            shortVersion: "1.0.0",
            buildNumber: "24"
        )

        XCTAssertEqual(info.versionDisplay, "版本 1.0.0")
        XCTAssertEqual(info.buildDisplay, "构建 24")
    }

    func testModelStorageDescriptionUsesUserReadablePath() {
        let info = ReadyTypeAboutInfo(
            shortVersion: "1.0.0",
            buildNumber: "24",
            speechPackageDirectoryPath: "/Users/me/Library/Application Support/ReadyType/Models"
        )

        XCTAssertEqual(
            info.speechPackageStorageDescription,
            "高精度语音包保存在 /Users/me/Library/Application Support/ReadyType/Models，可在设置里删除；以后需要更新时可重新下载。"
        )
    }
}
