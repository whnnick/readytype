import Foundation

@MainActor
protocol OutputProcessing: AnyObject {
    func process(_ transcript: String, mode: OutputMode) async throws -> ProcessedOutput
    func process(_ transcript: String, mode: OutputMode, scenario: OutputScenario) async throws -> ProcessedOutput
    func process(_ transcript: String, mode: OutputMode, context: OutputContext) async throws -> ProcessedOutput
}

struct ProcessedOutput: Equatable {
    let rawTranscript: String
    let finalText: String
    let usedAI: Bool
    let usedFallback: Bool
    let warning: ReadyTypeError?
}

final class OutputProcessor: OutputProcessing {
    private let providerFactory: () -> ChatCompletionProvider
    private let termCorrectionServiceProvider: () -> TermCorrectionService
    private let directDictationNormalizerProvider: () -> DirectDictationNormalizer
    private let userVocabularyTermsProvider: () -> [String]

    init(provider: ChatCompletionProvider) {
        self.providerFactory = { provider }
        self.termCorrectionServiceProvider = {
            TermCorrectionService(dictionary: .readyTypeDefault)
        }
        self.directDictationNormalizerProvider = {
            DirectDictationNormalizer(dictionary: .readyTypeDefault)
        }
        self.userVocabularyTermsProvider = { [] }
    }

    init(
        providerFactory: @escaping () -> ChatCompletionProvider,
        termCorrectionService: TermCorrectionService = TermCorrectionService(dictionary: .readyTypeDefault)
    ) {
        self.providerFactory = providerFactory
        self.termCorrectionServiceProvider = {
            termCorrectionService
        }
        self.directDictationNormalizerProvider = {
            DirectDictationNormalizer(dictionary: .readyTypeDefault)
        }
        self.userVocabularyTermsProvider = { [] }
    }

    init(
        providerFactory: @escaping () -> ChatCompletionProvider,
        termCorrectionServiceProvider: @escaping () -> TermCorrectionService
    ) {
        self.providerFactory = providerFactory
        self.termCorrectionServiceProvider = termCorrectionServiceProvider
        self.directDictationNormalizerProvider = {
            DirectDictationNormalizer(dictionary: .readyTypeDefault)
        }
        self.userVocabularyTermsProvider = { [] }
    }

    init(
        providerFactory: @escaping () -> ChatCompletionProvider,
        termCorrectionServiceProvider: @escaping () -> TermCorrectionService,
        directDictationNormalizerProvider: @escaping () -> DirectDictationNormalizer,
        userVocabularyTermsProvider: @escaping () -> [String] = { [] }
    ) {
        self.providerFactory = providerFactory
        self.termCorrectionServiceProvider = termCorrectionServiceProvider
        self.directDictationNormalizerProvider = directDictationNormalizerProvider
        self.userVocabularyTermsProvider = userVocabularyTermsProvider
    }

    func process(_ transcript: String, mode: OutputMode) async throws -> ProcessedOutput {
        try await process(transcript, mode: mode, scenario: .generic)
    }

    func process(_ transcript: String, mode: OutputMode, scenario: OutputScenario) async throws -> ProcessedOutput {
        try await process(transcript, mode: mode, context: OutputContext(scenario: scenario))
    }

    func process(_ transcript: String, mode: OutputMode, context: OutputContext) async throws -> ProcessedOutput {
        let rawTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !rawTranscript.isEmpty else {
            throw ReadyTypeError.transcriptionEmpty
        }

        guard mode.requiresAI else {
            let normalization = directDictationNormalizerProvider().normalize(rawTranscript)
            return ProcessedOutput(
                rawTranscript: rawTranscript,
                finalText: normalization.normalizedText,
                usedAI: false,
                usedFallback: false,
                warning: nil
            )
        }

        do {
            let prompt = PromptTemplates.systemPrompt(for: mode, context: context)
            let provider = providerFactory()
            let providerOutput = try await provider.complete(
                systemPrompt: prompt,
                userText: userTextWithTermCandidates(for: rawTranscript, context: context)
            )
            let finalText = providerOutput.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !finalText.isEmpty else {
                throw ReadyTypeError.deepSeekUnexpectedResponse
            }

            let normalizedFinalText = finalOutputText(
                from: finalText,
                rawTranscript: rawTranscript,
                context: context
            )

            return ProcessedOutput(
                rawTranscript: rawTranscript,
                finalText: normalizedFinalText,
                usedAI: true,
                usedFallback: false,
                warning: nil
            )
        } catch let error as ReadyTypeError {
            if Self.shouldStopUnsafeAIFallback(rawTranscript: rawTranscript, mode: mode) {
                throw error
            }
            return fallbackOutput(rawTranscript: rawTranscript, warning: error)
        } catch {
            if Self.shouldStopUnsafeAIFallback(rawTranscript: rawTranscript, mode: mode) {
                throw ReadyTypeError.deepSeekUnexpectedResponse
            }
            return fallbackOutput(rawTranscript: rawTranscript, warning: .deepSeekUnexpectedResponse)
        }
    }

    private static func shouldStopUnsafeAIFallback(rawTranscript: String, mode: OutputMode) -> Bool {
        switch mode {
        case .translationToEnglish, .promptOutput:
            true
        case .aiCleanup:
            SpokenOutputModeCommand.requiresAICapability(rawTranscript)
        case .dictation:
            false
        }
    }

    private func fallbackOutput(rawTranscript: String, warning: ReadyTypeError) -> ProcessedOutput {
        let normalization = directDictationNormalizerProvider().normalize(rawTranscript)

        return ProcessedOutput(
            rawTranscript: rawTranscript,
            finalText: normalization.normalizedText,
            usedAI: true,
            usedFallback: true,
            warning: warning
        )
    }

    private func finalOutputText(
        from text: String,
        rawTranscript: String,
        context: OutputContext
    ) -> String {
        var normalizedText = directDictationNormalizerProvider()
            .normalize(text)
            .normalizedText

        if context.scenario == .message {
            normalizedText = Self.removingLeadingRecipientInstruction(from: normalizedText)
            if let recipient = Self.recipientNameFromSendInstruction(in: rawTranscript) {
                normalizedText = Self.removingLeadingRecipientInstruction(
                    recipient: recipient,
                    from: normalizedText
                )
                normalizedText = Self.removingLeadingRecipientName(recipient, from: normalizedText)
            }
        }

        normalizedText = SpokenTailNoiseCleaner.cleanFinalOutput(normalizedText)
        return normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removingLeadingRecipientInstruction(from text: String) -> String {
        let patterns = [
            #"^\s*发给[\p{Han}A-Za-z0-9_·\s]{1,12}[：:]\s*"#,
            #"^\s*给[\p{Han}A-Za-z0-9_·\s]{1,12}发[：:]\s*"#
        ]

        return replacingFirstMatch(in: text, patterns: patterns, with: "")
    }

    private static func removingLeadingRecipientInstruction(
        recipient: String,
        from text: String
    ) -> String {
        let escapedRecipient = NSRegularExpression.escapedPattern(for: recipient)
        let patterns = [
            #"^\s*发给\#(escapedRecipient)\s*"#,
            #"^\s*给\#(escapedRecipient)发\s*"#
        ]

        return replacingFirstMatch(in: text, patterns: patterns, with: "")
    }

    private static func recipientNameFromSendInstruction(in text: String) -> String? {
        let patterns = [
            #"^\s*发给([\p{Han}A-Za-z0-9_·\s]{1,12})[，,：:\s]"#,
            #"^\s*给([\p{Han}A-Za-z0-9_·\s]{1,12})发[，,：:\s]"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard
                let match = regex.firstMatch(in: text, range: range),
                match.numberOfRanges > 1,
                let nameRange = Range(match.range(at: 1), in: text)
            else {
                continue
            }

            let name = String(text[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }

        return nil
    }

    private static func removingLeadingRecipientName(_ recipient: String, from text: String) -> String {
        let escapedRecipient = NSRegularExpression.escapedPattern(for: recipient)
        let patterns = [
            #"^\s*\#(escapedRecipient)[，,：:]\s*"#
        ]

        return replacingFirstMatch(in: text, patterns: patterns, with: "")
    }

    private static func replacingFirstMatch(
        in text: String,
        patterns: [String],
        with replacement: String
    ) -> String {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            guard regex.firstMatch(in: text, range: range) != nil else {
                continue
            }

            return regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: range,
                withTemplate: replacement
            )
        }

        return text
    }

    private func userTextWithTermCandidates(for rawTranscript: String, context: OutputContext) -> String {
        let termCorrectionService = termCorrectionServiceProvider()
        let suggestions = Array(
            termCorrectionService
                .suggestions(for: rawTranscript)
                .filter { Self.isTermCandidate($0, supportedBy: context.scenario) }
                .prefix(10)
        )
        let canonicalTerms = Self.canonicalTerms(userVocabularyTermsProvider())
        guard !suggestions.isEmpty || !canonicalTerms.isEmpty else {
            return rawTranscript
        }

        let hintLines = suggestions.map {
            "- \"\($0.original)\" may mean \"\($0.replacement)\""
        }

        let canonicalSection = canonicalTerms.isEmpty ? "" : """

        User-saved canonical spellings:
        \(canonicalTerms.map { "- \"\($0)\"" }.joined(separator: "\n"))

        These are vocabulary hints, not required content. Use a spelling only when the transcript sounds close and the surrounding context supports it.
        """

        let candidateSection = suggestions.isEmpty ? "" : """

        Possible ASR term candidates:
        \(hintLines.joined(separator: "\n"))

        Use these candidates only when the surrounding context clearly supports them. Do not add facts.
        """

        return """
        \(rawTranscript)
        \(canonicalSection)
        \(candidateSection)
        """
    }

    private static func canonicalTerms(_ terms: [String]) -> [String] {
        var seen: Set<String> = []
        return terms.compactMap { term in
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = trimmed.normalizedSmartTermKey
            guard !trimmed.isEmpty, !key.isEmpty, seen.insert(key).inserted else {
                return nil
            }
            return trimmed
        }
        .prefix(20)
        .map { $0 }
    }

    private static func isTermCandidate(
        _ suggestion: TermCorrectionSuggestion,
        supportedBy scenario: OutputScenario
    ) -> Bool {
        if suggestion.scopes.contains(.all) {
            return true
        }

        if suggestion.scopes.contains(.technical),
           scenario == .document || scenario == .aiTool || scenario == .generic {
            return true
        }

        if suggestion.scopes.contains(.chat), scenario == .message {
            return true
        }

        if suggestion.scopes.contains(.email), scenario == .email {
            return true
        }

        if suggestion.scopes.contains(.document), scenario == .document || scenario == .note {
            return true
        }

        if suggestion.scopes.contains(.aiTool), scenario == .aiTool {
            return true
        }

        return false
    }
}
