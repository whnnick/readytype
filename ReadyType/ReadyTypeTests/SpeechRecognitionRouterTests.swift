import XCTest
@testable import ReadyType

final class SpeechRecognitionRouterTests: XCTestCase {
    func testFastModeAlwaysUsesFastSystemBackend() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .fastSystem,
                scenario: .document,
                frontmostAppBundleIdentifier: "com.apple.dt.Xcode",
                recordingDuration: 30,
                hasLowConfidenceSignal: true,
                hasChineseMisclassifiedAsEnglishSignal: true,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: ["Kubernetes"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeUsesFastSystemForShortChatInput() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .message,
                frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                recordingDuration: 4,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: []
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeUsesHighAccuracyForLongDocumentWhenModelIsReady() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                recordingDuration: 18,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: ["ReadyType"]
            )
        )

        XCTAssertEqual(decision.backend, .highAccuracyLocal)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeUsesFastSystemForLongDocumentWhenHighAccuracyIsDownloadedButCold() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                recordingDuration: 18,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .downloadedCold,
                contextualTerms: ["ReadyType"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertEqual(decision.fallbackReason, "高精度识别正在准备，已使用极速识别。")
    }

    func testAutomaticModeUsesFastSystemForShortEmailEvenWhenModelIsReady() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .email,
                frontmostAppBundleIdentifier: "com.apple.TextEdit",
                recordingDuration: 5,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: ["张三", "预算表"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeUsesFastSystemForShortDocumentEvenWithContextualTerms() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .document,
                frontmostAppBundleIdentifier: "com.apple.TextEdit",
                recordingDuration: 6,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: ["ReadyType", "GitHub Actions", "README"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeFallsBackWhenHighAccuracyWouldHelpButModelIsMissing() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                recordingDuration: 20,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .notInstalled,
                contextualTerms: ["ReadyType"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertEqual(decision.fallbackReason, "高精度识别未就绪，已使用极速识别。")
    }

    func testAutomaticGenericInputDoesNotUseHighAccuracyOnlyBecauseGlobalTermsExist() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .generic,
                frontmostAppBundleIdentifier: "com.apple.TextEdit",
                recordingDuration: 4,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: ["ReadyType", "GitHub", "Kubernetes", "Redis"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertNil(decision.fallbackReason)
    }

    func testAutomaticModeFallsBackToFastSystemOnLowPowerMode() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .document,
                frontmostAppBundleIdentifier: "md.obsidian",
                recordingDuration: 20,
                hasLowConfidenceSignal: true,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: true,
                localModelState: .warm,
                contextualTerms: ["ReadyType"]
            )
        )

        XCTAssertEqual(decision.backend, .fastSystem)
        XCTAssertEqual(decision.fallbackReason, "低电量模式下已使用极速识别。")
    }

    func testExplicitHighAccuracyModeUsesLocalBackendWhenDownloadedCold() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .highAccuracyLocal,
                scenario: .message,
                frontmostAppBundleIdentifier: "com.tencent.xinWeChat",
                recordingDuration: 3,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: false,
                isLowPowerModeEnabled: false,
                localModelState: .downloadedCold,
                contextualTerms: []
            )
        )

        XCTAssertEqual(decision.backend, .highAccuracyLocal)
        XCTAssertNil(decision.fallbackReason)
    }

    func testChineseMisclassifiedAsEnglishSignalCanPromoteAutomaticMode() {
        let router = SpeechRecognitionRouter()

        let decision = router.route(
            context: SpeechRecognitionRouteContext(
                mode: .automatic,
                scenario: .generic,
                frontmostAppBundleIdentifier: nil,
                recordingDuration: 3,
                hasLowConfidenceSignal: false,
                hasChineseMisclassifiedAsEnglishSignal: true,
                isLowPowerModeEnabled: false,
                localModelState: .warm,
                contextualTerms: []
            )
        )

        XCTAssertEqual(decision.backend, .highAccuracyLocal)
        XCTAssertNil(decision.fallbackReason)
    }
}
