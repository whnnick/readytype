import XCTest
@testable import ReadyType

final class OutputScenarioTests: XCTestCase {
    func testBundleIdentifierMapsToKnownScenarios() {
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.mail", windowTitle: nil), .email)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.tencent.xinWeChat", windowTitle: nil), .message)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.larksuite.Feishu", windowTitle: nil), .message)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.todesktop.230313mzl4w4u92", windowTitle: nil), .aiTool)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.todesktop.230313mzl4w4u92", windowTitle: "Cursor"), .aiTool)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.dt.Xcode", windowTitle: nil), .document)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.Notes", windowTitle: nil), .note)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "md.obsidian", windowTitle: nil), .note)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "notion.id", windowTitle: nil), .note)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.microsoft.Word", windowTitle: nil), .document)
    }

    func testWindowTitleCanImproveScenarioWhenBundleIsBrowser() {
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.Safari", windowTitle: "ChatGPT"), .aiTool)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.google.Chrome", windowTitle: "Inbox - Gmail"), .email)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.Safari", windowTitle: "Notion - Project Notes"), .note)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.google.Chrome", windowTitle: "Google Docs - Product Plan"), .document)
    }

    func testBrowserWithoutSpecificTitleFallsBackToGeneric() {
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.apple.Safari", windowTitle: nil), .generic)
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.google.Chrome", windowTitle: nil), .generic)
    }

    func testTranscriptSemanticsImproveGenericScenario() {
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "我想写一封邮件给客户说明今天晚点发方案"),
            .email
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "给张三发一封邮件，第一项目延期，第二明天开会"),
            .email
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "帮我整理成待办，明天跟进合同和发票"),
            .note
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "帮我写一个给 AI 的任务，让它生成项目计划"),
            .aiTool
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "帮我整理一段发给张三的项目沟通内容，设计稿还没确认"),
            .message
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "帮我整理一段发给李四的微信消息，今天下午四点之前我会把会议纪要整理好"),
            .message
        )
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "发给李四，报价单第三项费用有问题，先别发给客户，OK"),
            .message
        )
    }

    func testKnownAppScenarioTakesPriorityOverTranscriptSemantics() {
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.todesktop.230313mzl4w4u92", windowTitle: nil, transcript: "帮我写一封邮件"),
            .aiTool
        )
    }

    func testInvoicePhraseDoesNotLookLikeChatSendInstruction() {
        XCTAssertEqual(
            OutputScenario.infer(bundleIdentifier: "com.example.editor", windowTitle: "Untitled", transcript: "给客户发票明天再开，先确认报价单"),
            .generic
        )
    }

    func testOutputContextDistinguishesPersonalAndWorkChatApps() {
        XCTAssertEqual(
            OutputContext.infer(
                bundleIdentifier: "com.tencent.xinWeChat",
                windowTitle: nil,
                transcript: "你工作的时候就用高级服务器，看视频就用那台"
            ),
            OutputContext(scenario: .message, chatTone: .personal)
        )
        XCTAssertEqual(
            OutputContext.infer(
                bundleIdentifier: "com.larksuite.Feishu",
                windowTitle: nil,
                transcript: "同步一下项目进度"
            ),
            OutputContext(scenario: .message, chatTone: .work)
        )
    }

    func testUnknownAppFallsBackToGeneric() {
        XCTAssertEqual(OutputScenario.infer(bundleIdentifier: "com.example.unknown", windowTitle: "Untitled"), .generic)
    }

    func testScenarioSelectionIncludesCommonUserFacingChoices() {
        XCTAssertEqual(OutputScenarioSelection.allCases.map(\.displayName), [
            "自动",
            "通用",
            "邮件",
            "聊天",
            "笔记",
            "AI 工具",
            "文档"
        ])
    }

    func testScenarioSelectionSummariesAreHiddenForDirectDictation() {
        XCTAssertNil(OutputScenarioSelection.automatic.compactSummary(for: .dictation))
        XCTAssertNil(OutputScenarioSelection.email.hudLabel(for: .dictation))
    }

    func testScenarioSelectionSummariesAppearForAIOutputMethods() {
        XCTAssertEqual(OutputScenarioSelection.automatic.compactSummary(for: .aiCleanup), "场景：自动")
        XCTAssertEqual(OutputScenarioSelection.email.compactSummary(for: .translationToEnglish), "场景：邮件")
        XCTAssertEqual(OutputScenarioSelection.aiTool.hudLabel(for: .promptOutput), "AI 工具")
    }
}
