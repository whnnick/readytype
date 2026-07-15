import XCTest
@testable import ReadyType

final class MotionTokensTests: XCTestCase {
    func testVoiceCapsuleUsesCompactStableDimensions() {
        XCTAssertEqual(MotionTokens.voiceCapsuleWindowSize.width, 420)
        XCTAssertEqual(MotionTokens.voiceCapsuleWindowSize.height, 82)
        XCTAssertEqual(MotionTokens.voiceCapsuleWidth, 246)
        XCTAssertEqual(MotionTokens.voiceCapsuleHeight, 44)
        XCTAssertEqual(MotionTokens.voiceCapsuleCornerRadius, 22)
        XCTAssertEqual(MotionTokens.escapeHintDuration, 1.6)
    }

    func testStandardMotionAllowsExpressiveHUDMovement() {
        let preferences = MotionPreferences(reduceMotion: false)

        XCTAssertEqual(MotionTokens.hudEntranceOffset(for: preferences), 12)
        XCTAssertTrue(MotionTokens.waveAnimationEnabled(for: preferences))
        XCTAssertTrue(MotionTokens.errorShakeEnabled(for: preferences))
        XCTAssertEqual(MotionTokens.voiceCapsuleCornerRadius, 22)
        XCTAssertEqual(MotionTokens.voiceCapsuleHeight, 44)
    }

    func testReducedMotionDisablesLargeMovementAndWaveAnimation() {
        let preferences = MotionPreferences(reduceMotion: true)

        XCTAssertEqual(MotionTokens.hudEntranceOffset(for: preferences), 0)
        XCTAssertFalse(MotionTokens.waveAnimationEnabled(for: preferences))
        XCTAssertFalse(MotionTokens.errorShakeEnabled(for: preferences))
        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .pasted, preferences: preferences), 1)
    }

    func testVoiceCapsuleSuccessAndErrorMotionAreScoped() {
        let preferences = MotionPreferences(reduceMotion: false)

        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .pasted, preferences: preferences), 1.018)
        XCTAssertEqual(MotionTokens.voiceCapsuleScale(for: .recording, preferences: preferences), 1)
    }
}
