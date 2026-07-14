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

    func testEventsMapOnlyToAllowlistedSignalProperties() {
        let signal = ReadyTypeAnalyticsEvent.voiceInputFinished(
            engine: .local,
            outputMethod: .polished,
            scenario: .email,
            recordingDuration: .fifteenTo30Seconds,
            completionLatency: .fifteenHundredTo3000Milliseconds,
            delivery: .pasted
        ).signal

        XCTAssertEqual(signal.name, "voice_input_finished")
        XCTAssertEqual(
            signal.parameters,
            [
                "engine": "local",
                "output_method": "polished",
                "scenario": "email",
                "recording_duration": "15_30s",
                "completion_latency": "1500_3000ms",
                "delivery": "pasted"
            ]
        )
    }

    func testTelemetryDeckTrackerSendsMappedSignal() {
        var receivedSignal: ReadyTypeAnalyticsSignal?
        let tracker = TelemetryDeckAnalyticsTracker(appID: "test-app") { name, parameters in
            receivedSignal = ReadyTypeAnalyticsSignal(name: name, parameters: parameters)
        }

        tracker.track(.voiceInputFailed(stage: .transcription, code: .transcriptionEmpty))

        XCTAssertEqual(
            receivedSignal,
            ReadyTypeAnalyticsSignal(
                name: "voice_input_failed",
                parameters: ["stage": "transcription", "code": "transcriptionEmpty"]
            )
        )
    }

    func testAnalyticsFactoryUsesNoopWithoutConfiguredAppID() {
        XCTAssertTrue(ReadyTypeAnalyticsFactory.make(appID: nil) is NoopAnalyticsTracker)
        XCTAssertTrue(ReadyTypeAnalyticsFactory.make(appID: "  ") is NoopAnalyticsTracker)
        XCTAssertTrue(ReadyTypeAnalyticsFactory.make(appID: "not-a-uuid") is NoopAnalyticsTracker)

        var configuredAppID: String?
        var configuredTestMode: Bool?
        let appID = "6D85C69C-5CA4-47B4-9712-A0B21F28704A"
        let tracker = ReadyTypeAnalyticsFactory.make(appID: "  \(appID)  ", testMode: true) { appID, testMode in
            configuredAppID = appID
            configuredTestMode = testMode
            return AnalyticsEventRecorder()
        }

        XCTAssertEqual(configuredAppID, appID)
        XCTAssertEqual(configuredTestMode, true)
        XCTAssertTrue(tracker is AnalyticsEventRecorder)
    }
}

@MainActor
private final class AnalyticsEventRecorder: AnalyticsTracking {
    private(set) var events: [ReadyTypeAnalyticsEvent] = []

    func track(_ event: ReadyTypeAnalyticsEvent) {
        events.append(event)
    }
}
