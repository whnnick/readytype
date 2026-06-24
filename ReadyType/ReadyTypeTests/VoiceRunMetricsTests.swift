import XCTest
@testable import ReadyType

final class VoiceRunMetricsTests: XCTestCase {
    func testSeparatesImmediateFeedbackFromRecognitionAndOutputTiming() {
        let metrics = VoiceRunMetrics(
            recordingStartedAt: Date(timeIntervalSince1970: 10),
            inputFeedbackShownAt: Date(timeIntervalSince1970: 10.2),
            recordingStoppedAt: Date(timeIntervalSince1970: 16),
            transcriptReadyAt: Date(timeIntervalSince1970: 17.5),
            outputCompletedAt: Date(timeIntervalSince1970: 19),
            recordingDuration: 6
        )

        XCTAssertEqual(metrics.inputFeedbackLatencyMilliseconds, 200)
        XCTAssertEqual(metrics.transcriptionLatencyMilliseconds, 1_500)
        XCTAssertEqual(metrics.stopToOutputLatencyMilliseconds, 3_000)
        XCTAssertEqual(metrics.totalCompletionLatencyMilliseconds, 9_000)
        XCTAssertEqual(metrics.summaryLine, "耗时：反馈 200ms / 识别 1500ms / 停止到输出 3000ms / 总计 9000ms")
    }
}
