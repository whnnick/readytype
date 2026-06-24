import XCTest
@testable import ReadyType

@MainActor
final class IdlePrewarmControllerTests: XCTestCase {
    func testStartWaitsForLaunchDelayBeforePrewarming() async {
        let warmup = MockWarmup()
        let sleeper = ControlledSleeper()
        let controller = IdlePrewarmController(
            warmupService: warmup,
            launchDelay: .milliseconds(500),
            sleeper: sleeper.sleep(for:)
        )

        controller.start()
        await Task.yield()

        let reasonsBeforeDelay = await warmup.reasons()
        XCTAssertEqual(reasonsBeforeDelay, [])

        await sleeper.resume()
        await controller.waitUntilIdle()

        let reasonsAfterDelay = await warmup.reasons()
        XCTAssertEqual(reasonsAfterDelay, ["launch-idle"])
    }

    func testStartSkipsPrewarmWhenRecordingBeginsDuringLaunchDelay() async {
        let warmup = MockWarmup()
        let sleeper = ControlledSleeper()
        let recordingState = RecordingState(isRecording: false)
        let controller = IdlePrewarmController(
            warmupService: warmup,
            launchDelay: .milliseconds(500),
            isRecording: { await recordingState.value },
            sleeper: sleeper.sleep(for:)
        )

        controller.start()
        await Task.yield()
        await recordingState.set(true)
        await sleeper.resume()
        await controller.waitUntilIdle()

        let reasons = await warmup.reasons()
        XCTAssertEqual(reasons, [])
    }

    func testStartNotifiesWhenPrewarmCompletes() async {
        let warmup = MockWarmup()
        let sleeper = ControlledSleeper()
        var observedStates: [LocalSpeechModelState] = []
        let controller = IdlePrewarmController(
            warmupService: warmup,
            launchDelay: .milliseconds(500),
            sleeper: sleeper.sleep(for:),
            onStateChange: { state in
                observedStates.append(state)
            }
        )

        controller.start()
        await Task.yield()
        await sleeper.resume()
        await controller.waitUntilIdle()

        XCTAssertEqual(observedStates, [.warm])
    }
}

private final class MockWarmup: LocalSpeechModelWarming, @unchecked Sendable {
    private(set) var state: LocalSpeechModelState = .downloadedCold
    private let storage = WarmupReasonStorage()

    func reasons() async -> [String] {
        await storage.values
    }

    func prewarmIfAllowed(reason: String) async {
        await storage.append(reason)
        state = .warm
    }

    func cancelPrewarm() {}
}

private actor WarmupReasonStorage {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private actor ControlledSleeper {
    private var continuation: CheckedContinuation<Void, Never>?
    private var shouldResumeImmediately = false

    func sleep(for duration: Duration) async {
        if shouldResumeImmediately {
            shouldResumeImmediately = false
            return
        }

        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        if let continuation {
            continuation.resume()
            self.continuation = nil
        } else {
            shouldResumeImmediately = true
        }
    }
}

private actor RecordingState {
    private var isRecording: Bool

    init(isRecording: Bool) {
        self.isRecording = isRecording
    }

    var value: Bool {
        isRecording
    }

    func set(_ value: Bool) {
        isRecording = value
    }
}
