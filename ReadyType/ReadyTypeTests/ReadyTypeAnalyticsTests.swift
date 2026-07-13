import XCTest
@testable import ReadyType

@MainActor
final class ReadyTypeAnalyticsTests: XCTestCase {
    func testConsentAwareTrackerDropsEventsWhenDisabled() {
        let recorder = AnalyticsEventRecorder()
        var isEnabled = false
        let tracker = ConsentAwareAnalyticsTracker(tracker: recorder) { isEnabled }

        tracker.track(.voiceInputCancelled(stage: .recording))
        XCTAssertTrue(recorder.events.isEmpty)

        isEnabled = true
        tracker.track(.voiceInputCancelled(stage: .recording))
        XCTAssertEqual(recorder.events, [.voiceInputCancelled(stage: .recording)])
    }

    func testDurationAndLatencyUseBoundedBuckets() {
        XCTAssertEqual(AnalyticsDurationBucket(seconds: 4.9), .under5Seconds)
        XCTAssertEqual(AnalyticsDurationBucket(seconds: 5), .fiveTo15Seconds)
        XCTAssertEqual(AnalyticsDurationBucket(seconds: 15), .fifteenTo30Seconds)
        XCTAssertEqual(AnalyticsDurationBucket(seconds: 30), .over30Seconds)

        XCTAssertEqual(AnalyticsLatencyBucket(milliseconds: 499), .under500Milliseconds)
        XCTAssertEqual(AnalyticsLatencyBucket(milliseconds: 500), .fiveHundredTo1500Milliseconds)
        XCTAssertEqual(AnalyticsLatencyBucket(milliseconds: 1_500), .fifteenHundredTo3000Milliseconds)
        XCTAssertEqual(AnalyticsLatencyBucket(milliseconds: 3_000), .over3000Milliseconds)
    }

    func testErrorsMapToFixedCodesWithoutAssociatedText() {
        XCTAssertEqual(ReadyTypeError.recordingFailed("private path").analyticsCode, .recording)
        XCTAssertEqual(ReadyTypeError.transcriptionFailed("raw transcript").analyticsCode, .transcription)
        XCTAssertEqual(ReadyTypeError.deepSeekModelError("provider response").analyticsCode, .apiModel)
        XCTAssertEqual(ReadyTypeError.keychainOperationFailed("account name").analyticsCode, .keychain)
    }
}

@MainActor
private final class AnalyticsEventRecorder: AnalyticsTracking {
    private(set) var events: [ReadyTypeAnalyticsEvent] = []

    func track(_ event: ReadyTypeAnalyticsEvent) {
        events.append(event)
    }
}

