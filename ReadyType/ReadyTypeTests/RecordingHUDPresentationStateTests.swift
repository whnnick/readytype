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

    func testRecordingActivationUsesPolicyDecisionForEscapeHint() {
        let state = RecordingHUDPresentationState()

        state.transition(from: .idle, to: .recording, showsEscapeHint: true)
        XCTAssertTrue(state.isEscapeHintVisible)

        state.dismissEscapeHint()
        XCTAssertFalse(state.isEscapeHintVisible)

        state.transition(from: .idle, to: .recording)
        XCTAssertFalse(state.isEscapeHintVisible)
    }

    func testEscapeHintReminderAppearsOnlyOnFirstActivationOfEachDay() {
        let suiteName = "RecordingHUDPresentationStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = EscapeHintReminderStore(defaults: defaults, calendar: calendar)
        let firstActivation = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 9))!
        let laterSameDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 22))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 7, day: 16, hour: 8))!

        XCTAssertTrue(store.shouldShowHint(at: firstActivation))
        store.recordActivation(at: firstActivation)
        XCTAssertFalse(store.shouldShowHint(at: laterSameDay))
        XCTAssertTrue(store.shouldShowHint(at: nextDay))
    }
}
