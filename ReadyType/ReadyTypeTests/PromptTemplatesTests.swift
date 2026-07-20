import XCTest
@testable import ReadyType

final class PromptTemplatesTests: XCTestCase {
    func testCleanupEmailScenarioIncludesEmailConstraints() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .email)

        XCTAssertTrue(prompt.contains("email"))
        XCTAssertTrue(prompt.contains("Do not add facts"))
        XCTAssertTrue(prompt.contains("recipients"))
        XCTAssertTrue(prompt.contains("greeting"))
        XCTAssertTrue(prompt.contains("closing"))
        XCTAssertTrue(prompt.contains("sign-off"))
        XCTAssertTrue(prompt.contains("numbered list"))
        XCTAssertTrue(prompt.contains("each item on its own line"))
        XCTAssertTrue(prompt.contains("Do not keep meta phrases"))
        XCTAssertTrue(prompt.contains("Do not add a subject line unless the transcript explicitly asks for a subject"))
        XCTAssertTrue(prompt.contains("Do not add signature placeholders"))
    }

    func testCleanupMessageScenarioRequestsShortMessageStyle() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .message)

        XCTAssertTrue(prompt.contains("short message"))
        XCTAssertTrue(prompt.contains("natural"))
        XCTAssertTrue(prompt.contains("Do not add facts"))
    }

    func testCleanupPersonalChatContextAvoidsOverPoliteWechatTone() {
        let prompt = PromptTemplates.systemPrompt(
            for: .aiCleanup,
            context: OutputContext(scenario: .message, chatTone: .personal)
        )

        XCTAssertTrue(prompt.contains("personal chat app"))
        XCTAssertTrue(prompt.contains("WeChat"))
        XCTAssertTrue(prompt.contains("Do not add thanks"))
        XCTAssertTrue(prompt.contains("Do not add formal greetings"))
        XCTAssertTrue(prompt.contains("Do not add polite closings"))
    }

    func testCleanupWorkChatContextStaysConciseWithoutBecomingEmail() {
        let prompt = PromptTemplates.systemPrompt(
            for: .aiCleanup,
            context: OutputContext(scenario: .message, chatTone: .work)
        )

        XCTAssertTrue(prompt.contains("work chat app"))
        XCTAssertTrue(prompt.contains("clear and concise"))
        XCTAssertTrue(prompt.contains("Do not turn it into an email"))
    }

    func testCleanupDocumentScenarioRequestsDocumentStyle() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .document)

        XCTAssertTrue(prompt.contains("document"))
        XCTAssertTrue(prompt.contains("paragraphs"))
        XCTAssertTrue(prompt.contains("heading"))
        XCTAssertTrue(prompt.contains("Do not add facts"))
        XCTAssertTrue(prompt.contains("Do not add greetings, thanks, acknowledgements, sign-offs, or closing phrases"))
    }

    func testPromptOutputAIToolScenarioRequestsStructuredPrompt() {
        let prompt = PromptTemplates.systemPrompt(for: .promptOutput, scenario: .aiTool)

        XCTAssertTrue(prompt.contains("task"))
        XCTAssertTrue(prompt.contains("context"))
        XCTAssertTrue(prompt.contains("constraints"))
        XCTAssertTrue(prompt.contains("Do not add facts"))
    }

    func testPromptOutputPromptDoesNotCompleteRequestedDeliverable() {
        let prompt = PromptTemplates.systemPrompt(for: .promptOutput, scenario: .aiTool)

        XCTAssertTrue(prompt.contains("Do not complete the user's requested deliverable"))
        XCTAssertTrue(prompt.contains("Do not invent acceptance metrics"))
        XCTAssertTrue(prompt.contains("Do not invent fallback providers"))
        XCTAssertTrue(prompt.contains("Do not invent examples"))
        XCTAssertTrue(prompt.contains("as output requirements, not as completed content"))
        XCTAssertTrue(prompt.contains("The final output must read like an instruction addressed to another AI assistant"))
        XCTAssertTrue(prompt.contains("Do not start with the requested deliverable title as if the deliverable is already written"))
        XCTAssertTrue(prompt.contains("Place requested sections under output requirements"))
    }

    func testTranslationModeRequestsEnglishOutputAndPreservesFacts() {
        let prompt = PromptTemplates.systemPrompt(for: .translationToEnglish, scenario: .email)

        XCTAssertTrue(prompt.contains("English"))
        XCTAssertTrue(prompt.contains("Do not add facts"))
        XCTAssertTrue(prompt.contains("email"))
        XCTAssertTrue(prompt.contains("Preserve"))
        XCTAssertTrue(prompt.contains("If the transcript names a recipient, use that recipient in the greeting"))
        XCTAssertTrue(prompt.contains("Do not add a subject line unless the transcript explicitly asks for a subject"))
        XCTAssertTrue(prompt.contains("numbered list"))
    }

    func testModePromptsUseUserFacingIntentNames() {
        XCTAssertTrue(PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .generic).contains("polished user-facing text"))
        XCTAssertTrue(PromptTemplates.systemPrompt(for: .translationToEnglish, scenario: .generic).contains("natural English"))
        XCTAssertTrue(PromptTemplates.systemPrompt(for: .promptOutput, scenario: .generic).contains("AI assistant"))
    }

    func testCleanupPromptPreservesCommonTechnicalTerms() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .generic)

        XCTAssertTrue(prompt.contains("ReadyType"))
        XCTAssertTrue(prompt.contains("GitHub"))
        XCTAssertTrue(prompt.contains("GitHub Actions"))
        XCTAssertTrue(prompt.contains("README"))
        XCTAssertTrue(prompt.contains("Kubernetes"))
        XCTAssertTrue(prompt.contains("Redis"))
        XCTAssertTrue(prompt.contains("Docker Compose"))
        XCTAssertTrue(prompt.contains("Option"))
        XCTAssertTrue(prompt.contains("Esc"))
        XCTAssertTrue(prompt.contains("do not turn Redis into Reddit"))
        XCTAssertTrue(prompt.contains("ReadyType into ReadyTap/Ready Tape/Reddit Type/Redis Type"))
        XCTAssertTrue(prompt.contains("README into Redmi"))
        XCTAssertTrue(prompt.contains("fast recognition into urgent recognition"))
    }

    func testCleanupPromptSeparatesInstructionsAndFiltersSpokenStopWords() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .message)

        XCTAssertTrue(prompt.contains("Treat spoken control phrases as instructions"))
        XCTAssertTrue(prompt.contains("帮我整理"))
        XCTAssertTrue(prompt.contains("发给某某"))
        XCTAssertTrue(prompt.contains("把这句话翻译成"))
        XCTAssertTrue(prompt.contains("Remove trailing spoken stop words"))
        XCTAssertTrue(prompt.contains("好了"))
        XCTAssertTrue(prompt.contains("就这样"))
    }

    func testCleanupPromptRestoresPunctuationForClearParallelItemsWithoutSplittingCompoundTerms() {
        let prompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .generic)

        XCTAssertTrue(prompt.contains("parallel items"))
        XCTAssertTrue(prompt.contains("list punctuation or line breaks"))
        XCTAssertTrue(prompt.contains("Do not split a compound term"))
        XCTAssertTrue(prompt.contains("grammar and context"))
    }

    func testTranslationPromptTreatsTranslationRequestAsInstruction() {
        let prompt = PromptTemplates.systemPrompt(for: .translationToEnglish, scenario: .generic)

        XCTAssertTrue(prompt.contains("把这句话翻译成英文"))
        XCTAssertTrue(prompt.contains("as instructions, not text to translate"))
    }

    func testAllAIModePromptsShareTermPreservationRules() {
        for mode in [OutputMode.aiCleanup, .translationToEnglish, .promptOutput] {
            let prompt = PromptTemplates.systemPrompt(for: mode, scenario: .aiTool)

            XCTAssertTrue(prompt.contains("ReadyType"))
            XCTAssertTrue(prompt.contains("DeepSeek"))
            XCTAssertTrue(prompt.contains("Redis"))
            XCTAssertTrue(prompt.contains("ReadyTap"))
            XCTAssertTrue(prompt.contains("DeepSeq"))
            XCTAssertTrue(prompt.contains("quotation sheet"))
            XCTAssertTrue(prompt.contains("Use the supplied ASR term candidates only when the surrounding context clearly supports them"))
        }
    }

    func testCleanupPromptForSendableMessagesPreservesRecipientIntent() {
        let genericPrompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .generic)
        let messagePrompt = PromptTemplates.systemPrompt(for: .aiCleanup, scenario: .message)

        XCTAssertTrue(genericPrompt.contains("directly sendable message"))
        XCTAssertTrue(genericPrompt.contains("Preserve the named recipient"))
        XCTAssertTrue(messagePrompt.contains("project communication content"))
        XCTAssertTrue(messagePrompt.contains("output the sendable message itself"))
    }

    func testDictationPromptIsEmptyForEveryScenario() {
        for scenario in OutputScenario.allCases {
            XCTAssertEqual(PromptTemplates.systemPrompt(for: .dictation, scenario: scenario), "")
        }
    }
}
