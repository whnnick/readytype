import XCTest
@testable import ReadyType

final class LocalSpeechModelReadinessTests: XCTestCase {
    func testInstalledDiskStateDoesNotDowngradeWarmRuntimeState() {
        XCTAssertEqual(
            LocalSpeechModelReadiness.displayState(
                diskState: .downloadedCold,
                runtimeState: .warm
            ),
            .warm
        )
    }

    func testInstalledDiskStateDoesNotDowngradeWarmingRuntimeState() {
        XCTAssertEqual(
            LocalSpeechModelReadiness.displayState(
                diskState: .downloadedCold,
                runtimeState: .warming
            ),
            .warming
        )
    }

    func testInstalledDiskStateDoesNotHideRuntimePreparationFailure() {
        XCTAssertEqual(
            LocalSpeechModelReadiness.displayState(
                diskState: .downloadedCold,
                runtimeState: .failed(reason: "准备失败")
            ),
            .failed(reason: "准备失败")
        )
    }

    func testMissingOrInvalidDiskStateOverridesRuntimeReadiness() {
        XCTAssertEqual(
            LocalSpeechModelReadiness.displayState(
                diskState: .notInstalled,
                runtimeState: .warm
            ),
            .notInstalled
        )
        XCTAssertEqual(
            LocalSpeechModelReadiness.displayState(
                diskState: .failed(reason: "模型校验失败"),
                runtimeState: .warm
            ),
            .failed(reason: "模型校验失败")
        )
    }
}
