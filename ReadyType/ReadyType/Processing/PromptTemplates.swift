import Foundation

enum PromptTemplates {
    static func systemPrompt(for mode: OutputMode) -> String {
        systemPrompt(for: mode, scenario: .generic)
    }

    static func systemPrompt(for mode: OutputMode, scenario: OutputScenario) -> String {
        systemPrompt(for: mode, context: OutputContext(scenario: scenario))
    }

    static func systemPrompt(for mode: OutputMode, context: OutputContext) -> String {
        switch mode {
        case .dictation:
            return ""
        case .aiCleanup:
            return cleanupPrompt
                + sharedTermPreservationPrompt
                + scenarioCleanupInstructions(for: context.scenario)
                + nonEmailCompletionInstructions(for: context.scenario)
                + chatToneInstructions(for: context.chatTone)
        case .translationToEnglish:
            return translationPrompt
                + sharedTermPreservationPrompt
                + scenarioTranslationInstructions(for: context.scenario)
                + nonEmailCompletionInstructions(for: context.scenario)
                + chatToneInstructions(for: context.chatTone)
        case .promptOutput:
            return promptWritingPrompt
                + sharedTermPreservationPrompt
                + scenarioPromptInstructions(for: context.scenario)
                + chatToneInstructions(for: context.chatTone)
        }
    }

    static let cleanupPrompt = """
    You turn spoken Chinese or English into polished user-facing text.
    Rewrite the user's speech transcript into clear, natural text that can be sent or saved directly.

    Rules:
    1. Preserve the user's original meaning.
    2. Do not add facts, names, dates, numbers, decisions, or commitments that the user did not provide.
    3. Remove obvious filler words and repeated fragments.
    4. Add punctuation and paragraph breaks when useful.
    5. Keep the output concise.
    6. Preserve common product and technical names when the transcript sounds like them.
    7. When a product or technical name is uncertain, keep the closest transcript spelling instead of replacing it with another real word or product name.
    8. Do not output placeholders such as [your name], [你的名字], [您的姓名], TODO, or TBD.
    9. Treat spoken control phrases as instructions, not body text. Remove prefixes such as "帮我整理...", "请帮我整理...", "发给某某...", "给某某发...", and "把这句话翻译成..." unless the user clearly wants those words in the final text.
    10. Remove trailing spoken stop words such as "OK", "好了", "就这样", "完成", "结束", and "先这样" when they only mark the end of dictation.
    11. Do not explain your changes.
    12. Output only the cleaned text.
    """

    static let promptWritingPrompt = """
    You turn spoken intent into a clear instruction for an AI assistant.
    Turn the user's speech transcript into a clear prompt that can be sent directly to an AI assistant.

    Rules:
    1. Preserve the user's original intent.
    2. Do not invent goals, constraints, files, data, dates, or requirements.
    3. Make the task explicit.
    4. Include relevant context only when it is present or clearly implied in the transcript.
    5. Include output requirements when useful.
    6. If the transcript is short, keep the prompt concise.
    7. Do not complete the user's requested deliverable; write the prompt that asks another AI to complete it.
    8. Treat requested sections such as user scenarios, core features, acceptance criteria, and risks as output requirements, not as completed content.
    9. Do not invent acceptance metrics, percentages, or time limits.
    10. Do not invent fallback providers, model names, or implementation choices.
    11. Do not invent examples, edge cases, or risk scenarios that the transcript did not provide.
    12. The final output must read like an instruction addressed to another AI assistant, for example "请根据以下信息生成...".
    13. Do not start with the requested deliverable title as if the deliverable is already written.
    14. Place requested sections under output requirements; do not write the section contents yourself.
    15. If details are missing, ask the next AI to infer carefully from the provided context or mark them as to be clarified; do not fill them in yourself.
    16. Remove trailing spoken stop words such as "OK", "好了", "就这样", "完成", "结束", and "先这样" when they only mark the end of dictation.
    17. Do not explain your changes.
    18. Output only the final prompt.
    """

    static let translationPrompt = """
    You translate spoken Chinese into natural English.
    Turn the user's speech transcript into clear English that can be sent or saved directly.

    Rules:
    1. Preserve the user's original meaning, tone, names, dates, numbers, and commitments.
    2. Do not add facts, names, dates, numbers, decisions, or commitments that the user did not provide.
    3. Remove obvious filler words and repeated fragments before translating.
    4. Use natural English phrasing, punctuation, and paragraph breaks when useful.
    5. Keep the output concise.
    6. Treat phrases such as "把这句话翻译成英文" or "翻译成英文" as instructions, not text to translate.
    7. Remove trailing spoken stop words such as "OK", "好了", "就这样", "完成", "结束", and "先这样" when they only mark the end of dictation.
    8. Do not explain your translation.
    9. Output only the final English text.
    """

    static let sharedTermPreservationPrompt = """

    Term and name preservation:
    - Preserve common product, technical, and work terms when the transcript sounds like them, including ReadyType, GitHub, GitHub Actions, README, Docker Compose, Kubernetes, Redis, Nextcloud, DeepSeek, Cursor, Xcode, API, CoreML, WhisperKit, Option, Esc, Command, Control, high-accuracy speech package, fast recognition, budget sheet, quotation sheet, todo items, capitalization, voice package, gray release, and ASR.
    - Use the supplied ASR term candidates only when the surrounding context clearly supports them.
    - Do not change an uncertain term into another real product or word just because it is common. For example, do not turn Redis into Reddit, ReadyType into ReadyTap/Ready Tape/Reddit Type/Redis Type, DeepSeek into DeepSeq, README into Redmi, quotation sheet into report sheet, high-accuracy voice package into high-accuracy language/silver package, fast recognition into urgent recognition, todo items into agency items, capitalization into big message, or gray release into return release.
    - If the candidate is unsupported by context, preserve the user's closest wording rather than inventing a correction.
    """

    private static func scenarioCleanupInstructions(for scenario: OutputScenario) -> String {
        switch scenario {
        case .generic:
            return """

            Scenario: generic text field.
            Keep the cleaned text broadly useful. Preserve the user's language. Do not add facts.
            If the transcript asks for content to send to a named person, output a directly sendable message rather than a generic description.
            Preserve the named recipient when it is natural to do so.
            """
        case .email:
            return """

            Scenario: email.
            Format the result as the email content itself when the transcript asks to write or send an email.
            If the transcript names a recipient, use that recipient in the greeting. If no recipient is provided, use a neutral greeting.
            Use readable body paragraphs and a polite closing/sign-off when appropriate.
            If the user lists points with words like first/second/third or 1/2/3, format those points as a numbered list with each item on its own line.
            If the transcript is messy, remove filler words, recover a clear order, and keep the tone natural and professional.
            Do not keep meta phrases such as "I want to write an email" or "help me write an email"; output the email content itself.
            Do not add a subject line unless the transcript explicitly asks for a subject.
            Do not add signature placeholders such as [your name], [你的名字], or [您的姓名]. If the user did not provide a sender name, end with a simple closing without a name.
            Do not add facts, recipients, dates, attachments, commitments, names, or decisions the user did not provide.
            """
        case .message:
            return """

            Scenario: chat message.
            Keep the output as a short message with a natural conversational tone.
            Prefer one compact paragraph unless the user clearly asked for multiple points.
            If the transcript names a recipient, keep that recipient when it makes the message clearer.
            If the transcript asks for project communication content to send to someone, output the sendable message itself.
            Do not make it sound like a formal report. Do not add facts.
            """
        case .aiTool:
            return """

            Scenario: AI tool input.
            Make the cleaned text useful for an AI assistant while preserving the user's intent.
            Prefer clear task wording, context, constraints, and output expectations only when present. Do not add facts.
            """
        case .note:
            return """

            Scenario: note.
            Preserve information hierarchy. Use a title, bullets, todos, or structured paragraphs when helpful.
            Do not turn uncertain statements into certain conclusions. Do not add facts.
            """
        case .document:
            return """

            Scenario: document.
            Write in a more formal document style with a clear heading when helpful and readable paragraphs.
            Use bullets only when they improve scanning. Do not add facts.
            """
        }
    }

    private static func chatToneInstructions(for tone: ChatTone) -> String {
        switch tone {
        case .default:
            return ""
        case .personal:
            return """

            Chat app tone: personal chat app, such as WeChat.
            Use direct everyday language that feels like a normal message in an existing chat thread.
            Do not add thanks unless the user said them.
            Do not add formal greetings or customer-service phrases unless the user said them.
            Do not add polite closings unless the user said them.
            Do not repeat the recipient name at the start unless it is necessary for clarity.
            """
        case .work:
            return """

            Chat app tone: work chat app.
            Keep the message clear and concise, but still conversational.
            Do not turn it into an email, report, title, or document outline.
            Do not add greetings, thanks, or sign-offs unless the user said them.
            """
        }
    }

    private static func nonEmailCompletionInstructions(for scenario: OutputScenario) -> String {
        guard scenario != .email else {
            return ""
        }

        return """

        Output fidelity:
        Do not add greetings, thanks, acknowledgements, sign-offs, or closing phrases unless the user said them.
        """
    }

    private static func scenarioPromptInstructions(for scenario: OutputScenario) -> String {
        switch scenario {
        case .generic:
            return """

            Scenario: generic AI prompt.
            Do not add facts. Keep the prompt direct and usable.
            """
        case .email:
            return """

            Scenario: email-writing prompt.
            Build a prompt that asks the AI to draft or improve an email.
            Include constraints about tone, recipients, dates, attachments, and commitments only when the user provided them. Do not add facts.
            """
        case .message:
            return """

            Scenario: chat message writing prompt.
            Build a prompt for a short message that sounds natural and concise.
            Do not add facts or make it overly formal.
            """
        case .aiTool:
            return """

            Scenario: AI tool.
            Build a structured prompt with task, context, constraints, and output format when useful.
            The final prompt should tell the next AI what to create and what sections to include.
            Do not add facts, files, technologies, dates, fallback providers, examples, or acceptance criteria that the user did not provide.
            """
        case .note:
            return """

            Scenario: note-taking prompt.
            Build a prompt that organizes information into notes, bullets, or todos.
            Do not add facts or convert uncertainty into certainty.
            """
        case .document:
            return """

            Scenario: document-writing prompt.
            Build a prompt that asks the AI to write or improve a document with clear structure, paragraphs, and a practical heading when useful.
            Include audience, tone, length, and output format only when the user provided them. Do not add facts.
            """
        }
    }

    private static func scenarioTranslationInstructions(for scenario: OutputScenario) -> String {
        switch scenario {
        case .generic:
            return """

            Scenario: generic English text.
            Preserve the user's intent and produce broadly useful natural English. Do not add facts.
            """
        case .email:
            return """

            Scenario: English email.
            Format the result as the email content itself when the transcript asks to write or send an email.
            If the transcript names a recipient, use that recipient in the greeting. Do not omit the recipient.
            If no recipient is provided, use a neutral greeting.
            Preserve recipients, greetings, numbered points, attachments, dates, and sign-offs only when the user provided them.
            If the user asks for 1/2/3, first/second/third, or numbered points, format those points as a numbered list with each item on its own line.
            Use readable paragraphs and a polite professional tone. Do not add facts.
            Do not add a subject line unless the transcript explicitly asks for a subject.
            """
        case .message:
            return """

            Scenario: English chat message.
            Keep the output as a natural short chat message.
            Prefer one compact paragraph unless the user clearly asked for multiple points. Do not add facts.
            """
        case .aiTool:
            return """

            Scenario: English AI tool input.
            Translate into a clear English instruction for an AI assistant.
            Preserve task, context, constraints, and output requirements only when present. Do not add facts.
            """
        case .note:
            return """

            Scenario: English note.
            Preserve information hierarchy and translate into clear notes, bullets, or todos when helpful.
            Do not turn uncertain statements into certain conclusions. Do not add facts.
            """
        case .document:
            return """

            Scenario: English document.
            Translate into a formal document style with readable paragraphs and a clear heading when useful.
            Use bullets only when they improve scanning. Do not add facts.
            """
        }
    }
}
