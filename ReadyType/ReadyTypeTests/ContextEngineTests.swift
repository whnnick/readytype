import Foundation
import XCTest
@testable import ReadyType

final class ContextEngineTests: XCTestCase {
    private let engine = ContextEngine()

    func testKnownAppsResolveToOneContextDecision() {
        let personalChat = engine.resolve(
            ContextRequest(bundleIdentifier: "com.tencent.xinWeChat")
        )
        XCTAssertEqual(personalChat.appProfile, .personalChat)
        XCTAssertEqual(personalChat.scenario, .message)
        XCTAssertEqual(personalChat.chatTone, .personal)
        XCTAssertEqual(personalChat.intent, .composeMessage)
        XCTAssertEqual(personalChat.outputTone, .personal)
        XCTAssertEqual(personalChat.confidence, .high)
        XCTAssertEqual(personalChat.reasons, [.bundleIdentifier])

        let workChat = engine.resolve(
            ContextRequest(bundleIdentifier: "com.larksuite.Feishu")
        )
        XCTAssertEqual(workChat.appProfile, .workChat)
        XCTAssertEqual(workChat.scenario, .message)
        XCTAssertEqual(workChat.chatTone, .work)
        XCTAssertEqual(workChat.outputTone, .work)
    }

    func testWindowTitleKeepsPriorityOverBundleAndTranscript() {
        let decision = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.apple.Safari",
                windowTitle: "Inbox - Gmail",
                transcript: "帮我整理成待办"
            )
        )

        XCTAssertEqual(decision.appProfile, .email)
        XCTAssertEqual(decision.scenario, .email)
        XCTAssertEqual(decision.intent, .composeEmail)
        XCTAssertEqual(decision.reasons, [.windowTitle])
    }

    func testLegacyCategoryOrderIsPreservedWhenBundleAndTitleConflict() {
        let mailShowingDocument = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.apple.mail",
                windowTitle: "Google Docs - Draft"
            )
        )
        XCTAssertEqual(mailShowingDocument.scenario, .email)
        XCTAssertEqual(mailShowingDocument.reasons, [.bundleIdentifier])

        let xcodeShowingNotes = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.apple.dt.Xcode",
                windowTitle: "Project Notes"
            )
        )
        XCTAssertEqual(xcodeShowingNotes.scenario, .document)
        XCTAssertEqual(xcodeShowingNotes.reasons, [.bundleIdentifier])
    }

    func testManualScenarioKeepsExistingOverrideBehavior() {
        let decision = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.apple.mail",
                transcript: "帮我写一封邮件",
                manualScenario: .message
            )
        )

        XCTAssertEqual(decision.appProfile, .email)
        XCTAssertEqual(decision.scenario, .message)
        XCTAssertEqual(decision.chatTone, .default)
        XCTAssertEqual(decision.intent, .composeMessage)
        XCTAssertEqual(decision.reasons, [.manualSelection])
    }

    func testTranscriptSemanticsAreUsedOnlyAfterAppProfileFallback() {
        let semanticDecision = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.example.editor",
                windowTitle: "Untitled",
                transcript: "帮我整理成待办，明天跟进合同"
            )
        )
        XCTAssertEqual(semanticDecision.appProfile, .generic)
        XCTAssertEqual(semanticDecision.scenario, .note)
        XCTAssertEqual(semanticDecision.intent, .captureNote)
        XCTAssertEqual(semanticDecision.confidence, .medium)
        XCTAssertEqual(semanticDecision.reasons, [.transcriptSemantics])

        let appDecision = engine.resolve(
            ContextRequest(
                bundleIdentifier: "com.todesktop.230313mzl4w4u92",
                transcript: "帮我写一封邮件"
            )
        )
        XCTAssertEqual(appDecision.appProfile, .aiTool)
        XCTAssertEqual(appDecision.scenario, .aiTool)
        XCTAssertEqual(appDecision.reasons, [.bundleIdentifier])
    }

    func testUnknownContextUsesExplicitFallback() {
        let decision = engine.resolve(
            ContextRequest(bundleIdentifier: "com.example.unknown", windowTitle: "Untitled")
        )

        XCTAssertEqual(decision.appProfile, .generic)
        XCTAssertEqual(decision.scenario, .generic)
        XCTAssertEqual(decision.chatTone, .default)
        XCTAssertEqual(decision.intent, .dictation)
        XCTAssertEqual(decision.outputTone, .neutral)
        XCTAssertEqual(decision.confidence, .fallback)
        XCTAssertEqual(decision.reasons, [.fallback])
    }

    func testContextResolutionP95StaysUnderTenMilliseconds() {
        let requests = [
            ContextRequest(bundleIdentifier: "com.tencent.xinWeChat", transcript: "同步一下"),
            ContextRequest(bundleIdentifier: "com.larksuite.Feishu", transcript: "同步项目进度"),
            ContextRequest(bundleIdentifier: "com.apple.Safari", windowTitle: "Inbox - Gmail"),
            ContextRequest(bundleIdentifier: "com.google.Chrome", windowTitle: "Google Docs"),
            ContextRequest(bundleIdentifier: "com.example.editor", transcript: "帮我整理成待办"),
            ContextRequest(bundleIdentifier: "com.example.unknown")
        ]
        var samples: [Double] = []

        for index in 0..<500 {
            let started = DispatchTime.now().uptimeNanoseconds
            _ = engine.resolve(requests[index % requests.count])
            samples.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
        }

        let sorted = samples.sorted()
        let p95 = sorted[Int(ceil(Double(sorted.count) * 0.95)) - 1]
        print(String(format: "Context Engine benchmark: samples=%d p95=%.3fms", samples.count, p95))
        XCTAssertLessThan(p95, 10)
    }
}
