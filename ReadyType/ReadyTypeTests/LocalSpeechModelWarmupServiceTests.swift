import XCTest
@testable import ReadyType

@MainActor
final class LocalSpeechModelWarmupServiceTests: XCTestCase {
    func testPrewarmWarmsDownloadedModelWhenAllConditionsAllow() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "test")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 1)
        XCTAssertEqual(service.state, .warm)
    }

    func testPrewarmDoesNothingWhenHighAccuracyIsDisabled() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { false },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "test")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    func testPrewarmDoesNothingWhileRecording() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { true },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "test")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    func testPrewarmDoesNothingBeforeLaunchDelayIsSatisfied() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false },
                isLaunchDelaySatisfied: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "launch")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    func testPrewarmDoesNothingInLowPowerMode() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { true },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "low-power")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    func testPrewarmDoesNothingWhenSystemIsUnderPressure() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { true }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "thermal-pressure")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .downloadedCold)
    }

    func testPrewarmDoesNothingWhenModelIsNotInstalled() async {
        let warmupCounter = WarmupCounter()
        let service = LocalSpeechModelWarmupService(
            initialState: .notInstalled,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                await warmupCounter.increment()
            }
        )

        await service.prewarmIfAllowed(reason: "test")

        let warmupCallCount = await warmupCounter.value
        XCTAssertEqual(warmupCallCount, 0)
        XCTAssertEqual(service.state, .notInstalled)
    }

    func testPrewarmFailureOnlyUpdatesStateAndDoesNotThrow() async {
        let service = LocalSpeechModelWarmupService(
            initialState: .downloadedCold,
            policy: .init(
                isHighAccuracyRecognitionEnabled: { true },
                isIdlePrewarmEnabled: { true },
                isRecording: { false },
                isLowPowerModeEnabled: { false },
                isSystemUnderPressure: { false }
            ),
            warmup: {
                throw ReadyTypeError.transcriptionFailed("warmup failed")
            }
        )

        await service.prewarmIfAllowed(reason: "test")

        XCTAssertEqual(service.state, .failed(reason: "更准确的识别准备失败：warmup failed"))
    }

    func testCancelPrewarmReturnsWarmingStateToDownloadedCold() {
        let service = LocalSpeechModelWarmupService(
            initialState: .warming,
            policy: .alwaysAllow,
            warmup: {}
        )

        service.cancelPrewarm()

        XCTAssertEqual(service.state, .downloadedCold)
    }
}

private actor WarmupCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
