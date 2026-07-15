import XCTest
@testable import ReadyType

@MainActor
final class RecordingHUDPresentationStateTests: XCTestCase {
    func testRecordingAndProcessingPhasesReceiveIndependentStartTimes() {
        let state = RecordingHUDPresentationState()
        let recordingDate = Date(timeIntervalSince1970: 100)
        let processingDate = Date(timeIntervalSince1970: 120)

        state.transition(from: .idle, to: .recording, now: recordingDate)
        state.transition(from: .recording, to: .transcribing, now: processingDate)

        XCTAssertEqual(state.recordingStartedAt, recordingDate)
        XCTAssertEqual(state.processingStartedAt, processingDate)
    }

    func testRepeatedStateUpdateDoesNotRestartProgress() {
        let state = RecordingHUDPresentationState()
        let initialDate = Date(timeIntervalSince1970: 100)

        state.transition(from: .recording, to: .transcribing, now: initialDate)
        state.transition(
            from: .transcribing,
            to: .transcribing,
            now: Date(timeIntervalSince1970: 130)
        )

        XCTAssertEqual(state.processingStartedAt, initialDate)
    }
}
