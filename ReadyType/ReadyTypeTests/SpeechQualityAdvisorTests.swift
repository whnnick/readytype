import XCTest
@testable import ReadyType

final class SpeechQualityAdvisorTests: XCTestCase {
    func testSuggestsHighAccuracyWhenChineseFocusedTranscriptLooksEnglish() {
        let advisory = SpeechQualityAdvisor.advisory(
            for: SpeechQualityAdvisoryRequest(
                transcript: "I want to send an email to John about the project delay",
                recognitionMode: .automatic,
                isHighAccuracyRecognitionEnabled: false,
                localSpeechModelState: .notInstalled
            )
        )

        XCTAssertEqual(
            advisory?.message,
            "识别结果偏英文；如果你刚才说的是中文，可在设置中启用更准确的本机识别。"
        )
    }

    func testDoesNotSuggestWhenTranscriptContainsChinese() {
        let advisory = SpeechQualityAdvisor.advisory(
            for: SpeechQualityAdvisoryRequest(
                transcript: "我想给张三发一封邮件，说明项目会晚两天。",
                recognitionMode: .automatic,
                isHighAccuracyRecognitionEnabled: false,
                localSpeechModelState: .notInstalled
            )
        )

        XCTAssertNil(advisory)
    }

    func testDoesNotSuggestWhenHighAccuracyIsReady() {
        let advisory = SpeechQualityAdvisor.advisory(
            for: SpeechQualityAdvisoryRequest(
                transcript: "This transcript is mostly English and long enough",
                recognitionMode: .highAccuracyLocal,
                isHighAccuracyRecognitionEnabled: true,
                localSpeechModelState: .warm
            )
        )

        XCTAssertNil(advisory)
    }
}
