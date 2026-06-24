import XCTest
@testable import ReadyType

final class RecordingPolicyTests: XCTestCase {
    func testDefaultMaximumRecordingDurationIsLongEnoughForNaturalDictation() {
        XCTAssertEqual(RecordingPolicy.defaultMaximumDuration, .seconds(60))
        XCTAssertEqual(RecordingPolicy.defaultMaximumDurationSeconds, 60)
    }

    func testAutoFinishMessageUsesVisibleDuration() {
        XCTAssertEqual(
            RecordingPolicy.autoFinishMessage,
            "本次语音输入达到 60 秒上限，正在识别..."
        )
    }
}
