import XCTest
@testable import ReadyType

final class SelectionIntentResolverTests: XCTestCase {
    private let resolver = SelectionIntentResolver()

    func testResolvesEachSupportedExplicitSelectionAction() {
        let fixtures: [(String, SelectionAction)] = [
            ("把这段话缩短一点", .shorten),
            ("把选中的文字扩写得详细一些", .expand),
            ("让这段文字更自然一些", .naturalize),
            ("把这封邮件写得更正式", .formalize),
            ("帮我整理一下这段话", .organize),
            ("把这段话翻译成英文", .translateToEnglish),
            ("帮我回复这条消息，说明明天下午三点可以", .reply)
        ]

        for (transcript, action) in fixtures {
            XCTAssertEqual(
                resolver.resolve(transcript: transcript, hasActiveSelection: true),
                .selectionAction(ResolvedSelectionAction(action: action, spokenInstruction: transcript)),
                transcript
            )
        }
    }

    func testResolvesCompactStandaloneCommands() {
        let fixtures: [(String, SelectionAction)] = [
            ("缩短一点", .shorten),
            ("扩写详细一点", .expand),
            ("改得自然一点", .naturalize),
            ("改得正式一点", .formalize),
            ("整理一下", .organize),
            ("翻译成英文", .translateToEnglish),
            ("帮我回复一下", .reply)
        ]

        for (transcript, action) in fixtures {
            XCTAssertEqual(
                resolver.resolve(transcript: transcript, hasActiveSelection: true),
                .selectionAction(ResolvedSelectionAction(action: action, spokenInstruction: transcript)),
                transcript
            )
        }
    }

    func testNeverResolvesWithoutActiveSelection() {
        XCTAssertEqual(
            resolver.resolve(transcript: "把这段话翻译成英文", hasActiveSelection: false),
            .ordinaryInput
        )
    }

    func testKeepsDescriptiveSpeechAsOrdinaryInput() {
        let fixtures = [
            "今天需要缩短会议时间",
            "回复张三说下午三点可以",
            "英文版本需要明天发布",
            "我想把这个项目扩写成一篇文章",
            "我觉得这段话需要更正式的版本",
            "这段话讨论如何缩短会议时间"
        ]

        for transcript in fixtures {
            XCTAssertEqual(
                resolver.resolve(transcript: transcript, hasActiveSelection: true),
                .ordinaryInput,
                transcript
            )
        }
    }

    func testAllowsActionImmediatelyAfterExplicitTarget() {
        XCTAssertEqual(
            resolver.resolve(transcript: "这段话精简一点", hasActiveSelection: true),
            .selectionAction(
                ResolvedSelectionAction(
                    action: .shorten,
                    spokenInstruction: "这段话精简一点"
                )
            )
        )
    }

    func testRejectsMultipleActionsInsteadOfChoosingArbitrarily() {
        let fixtures = [
            "把这段话缩短并翻译成英文",
            "把这段话整理并缩短"
        ]

        for transcript in fixtures {
            XCTAssertEqual(
                resolver.resolve(transcript: transcript, hasActiveSelection: true),
                .ordinaryInput,
                transcript
            )
        }
    }

    func testSpecificStyleActionTakesPriorityOverGenericOrganizeWording() {
        let fixtures: [(String, SelectionAction)] = [
            ("把这段话整理得更正式", .formalize),
            ("把这段话润色得更自然", .naturalize)
        ]

        for (transcript, action) in fixtures {
            XCTAssertEqual(
                resolver.resolve(transcript: transcript, hasActiveSelection: true),
                .selectionAction(
                    ResolvedSelectionAction(action: action, spokenInstruction: transcript)
                ),
                transcript
            )
        }
    }

    func testRejectsOverlongOrEmptyInstruction() {
        XCTAssertEqual(
            resolver.resolve(transcript: "   ", hasActiveSelection: true),
            .ordinaryInput
        )
        XCTAssertEqual(
            resolver.resolve(
                transcript: "把这段话缩短一点" + String(repeating: "补充", count: 120),
                hasActiveSelection: true
            ),
            .ordinaryInput
        )
    }

    func testTrimsResolvedSpokenInstruction() {
        XCTAssertEqual(
            resolver.resolve(transcript: "  翻译成英文。  ", hasActiveSelection: true),
            .selectionAction(
                ResolvedSelectionAction(
                    action: .translateToEnglish,
                    spokenInstruction: "翻译成英文。"
                )
            )
        )
    }
}
