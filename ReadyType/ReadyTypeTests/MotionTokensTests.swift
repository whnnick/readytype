import XCTest
@testable import ReadyType

final class MotionTokensTests: XCTestCase {
    func testVoiceCapsuleUsesCompactStableDimensions() {
        XCTAssertEqual(MotionTokens.voiceCapsuleWindowSize.width, 420)
        XCTAssertEqual(MotionTokens.voiceCapsuleWindowSize.height, 62)
        XCTAssertEqual(MotionTokens.voiceCapsuleHeight, 52)
        XCTAssertEqual(MotionTokens.processingCapsuleWidth, 154)
        XCTAssertEqual(MotionTokens.processingCapsuleHeight, 40)
    }

    func testOnlyRecognitionAndPolishingUseMinimalProcessingCapsule() {
        XCTAssertTrue(MotionTokens.usesMinimalProcessingCapsule(for: .transcribing))
        XCTAssertTrue(MotionTokens.usesMinimalProcessingCapsule(for: .processingAI))
        XCTAssertFalse(MotionTokens.usesMinimalProcessingCapsule(for: .recording))
        XCTAssertFalse(MotionTokens.usesMinimalProcessingCapsule(for: .pasted))
        XCTAssertFalse(MotionTokens.usesMinimalProcessingCapsule(for: .error("x")))
    }

    func testStandardMotionAllowsExpressiveHUDMovement() {
        let preferences = MotionPreferences(reduceMotion: false)

        XCTAssertEqual(MotionTokens.hudEntranceOffset(for: preferences), 12)
        XCTAssertTrue(MotionTokens.waveAnimationEnabled(for: preferences))
        XCTAssertTrue(MotionTokens.errorShakeEnabled(for: preferences))
        XCTAssertTrue(MotionTokens.voiceCapsuleFlowEnabled(for: .recording, preferences: preferences))
        XCTAssertEqual(MotionTokens.voiceCapsuleCornerRadius, 26)
        XCTAssertEqual(MotionTokens.voiceCapsuleHeight, 52)
    }

    func testReducedMotionDisablesLargeMovementAndWaveAnimation() {
        let preferences = MotionPreferences(reduceMotion: true)

        XCTAssertEqual(MotionTokens.hudEntranceOffset(for: preferences), 0)
        XCTAssertFalse(MotionTokens.waveAnimationEnabled(for: preferences))
        XCTAssertFalse(MotionTokens.errorShakeEnabled(for: preferences))
        XCTAssertFalse(MotionTokens.voiceCapsuleFlowEnabled(for: .recording, preferences: preferences))
        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .pasted, preferences: preferences), 1)
    }

    func testVoiceCapsuleFlowUsesDifferentRhythmsByRuntimeState() {
        let preferences = MotionPreferences(reduceMotion: false)

        XCTAssertFalse(MotionTokens.voiceCapsuleFlowEnabled(for: .idle, preferences: preferences))
        XCTAssertEqual(MotionTokens.voiceCapsuleFlowDuration(for: .recording), 1.55)
        XCTAssertEqual(MotionTokens.voiceCapsuleFlowDuration(for: .transcribing), 2.05)
        XCTAssertEqual(MotionTokens.voiceCapsuleFlowDuration(for: .processingAI), 2.35)
        XCTAssertGreaterThan(
            MotionTokens.voiceCapsuleFlowOpacity(for: .recording, preferences: preferences),
            MotionTokens.voiceCapsuleFlowOpacity(for: .processingAI, preferences: preferences)
        )
        XCTAssertGreaterThan(
            MotionTokens.voiceCapsuleFlowOpacity(for: .pasted, preferences: preferences),
            MotionTokens.voiceCapsuleFlowOpacity(for: .copiedFallback, preferences: preferences)
        )
    }

    func testVoiceCapsuleSuccessAndErrorMotionAreScoped() {
        let preferences = MotionPreferences(reduceMotion: false)

        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .pasted, preferences: preferences), 1.018)
        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .recording, preferences: preferences), 1)
        XCTAssertTrue(MotionTokens.voiceCapsuleErrorPulseEnabled(for: .error("x"), preferences: preferences))
        XCTAssertFalse(MotionTokens.voiceCapsuleErrorPulseEnabled(for: .recording, preferences: preferences))
    }
}
