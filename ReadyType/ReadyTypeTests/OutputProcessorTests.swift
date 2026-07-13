import XCTest
@testable import ReadyType

@MainActor
final class OutputProcessorTests: XCTestCase {
    func testDictationReturnsRawTranscriptWithoutCallingProvider() async throws {
        let provider = MockChatCompletionProvider(result: "should not be used")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(" raw spoken text ", mode: .dictation)

        XCTAssertEqual(result.finalText, "raw spoken text")
        XCTAssertEqual(result.rawTranscript, "raw spoken text")
        XCTAssertFalse(result.usedAI)
        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(provider.requests.count, 0)
    }

    func testDictationAppliesLocalTermProtectionWithoutCallingProvider() async throws {
        let provider = MockChatCompletionProvider(result: "should not be used")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process("请更新 read me 文档", mode: .dictation)

        XCTAssertEqual(result.rawTranscript, "请更新 read me 文档")
        XCTAssertEqual(result.finalText, "请更新 README 文档")
        XCTAssertFalse(result.usedAI)
        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(provider.requests.count, 0)
    }

    func testDictationRemovesTrailingSpokenNoiseWithoutCallingProvider() async throws {
        let provider = MockChatCompletionProvider(result: "should not be used")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "今天先不要继续加新功能先复测微信粘贴流程检查近音词保护和权限说明好谢谢大家",
            mode: .dictation
        )

        XCTAssertEqual(result.finalText, "今天先不要继续加新功能先复测微信粘贴流程检查近音词保护和权限说明")
        XCTAssertFalse(result.usedAI)
        XCTAssertEqual(provider.requests.count, 0)
    }

    func testAICleanupUsesProviderWithCleanupPrompt() async throws {
        let provider = MockChatCompletionProvider(result: "Clean text.")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process("um clean this up", mode: .aiCleanup, scenario: .email)

        XCTAssertEqual(result.finalText, "Clean text.")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("polished user-facing text"))
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("email"))
        XCTAssertEqual(provider.requests[0].userText, "um clean this up")
    }

    func testAICleanupIncludesBoundedUserVocabularyHints() async throws {
        let provider = MockChatCompletionProvider(result: "我平时用 Typeless，也会看 Reddit。")
        let processor = OutputProcessor(
            providerFactory: { provider },
            termCorrectionServiceProvider: {
                TermCorrectionService(dictionary: .readyTypeDefault)
            },
            directDictationNormalizerProvider: {
                DirectDictationNormalizer(dictionary: .readyTypeDefault)
            },
            userVocabularyTermsProvider: {
                ["Typeless", "Reddit", "Typeless"] + (0..<30).map { "Term\($0)" }
            }
        )

        _ = try await processor.process(
            "我平时用tape like也会看reddit",
            mode: .aiCleanup,
            scenario: .generic
        )

        let userText = try XCTUnwrap(provider.requests.first?.userText)
        XCTAssertTrue(userText.contains("User-saved canonical spellings:"))
        XCTAssertTrue(userText.contains("\"Typeless\""))
        XCTAssertTrue(userText.contains("\"Reddit\""))
        XCTAssertEqual(userText.components(separatedBy: "\"Typeless\"").count - 1, 1)
        XCTAssertFalse(userText.contains("\"Term20\""))
        XCTAssertTrue(userText.contains("not required content"))
    }

    func testAICleanupUsesChatToneContextInPrompt() async throws {
        let provider = MockChatCompletionProvider(result: "你工作的时候用高级服务器，看视频就用那台。")
        let processor = OutputProcessor(provider: provider)

        _ = try await processor.process(
            "你工作的时候就用高级服务器看视频就用那台这样就够用了谢谢",
            mode: .aiCleanup,
            context: OutputContext(scenario: .message, chatTone: .personal)
        )

        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("personal chat app"))
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("Do not add thanks"))
    }

    func testAICleanupSendsTermCandidatesWithoutReplacingTranscript() async throws {
        let provider = MockChatCompletionProvider(result: "请将 ReadyType 配置文档同步到 GitHub。")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "请把ReadyType的配置文档同步到get up",
            mode: .aiCleanup,
            scenario: .document
        )

        XCTAssertEqual(result.rawTranscript, "请把ReadyType的配置文档同步到get up")
        XCTAssertEqual(result.finalText, "请将 ReadyType 配置文档同步到 GitHub。")
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].userText.contains("请把ReadyType的配置文档同步到get up"))
        XCTAssertTrue(provider.requests[0].userText.contains("\"get up\" may mean \"GitHub\""))
        XCTAssertTrue(provider.requests[0].userText.contains("Use these candidates only when the surrounding context clearly supports them"))
    }

    func testAIModesSendAcceptanceTermCandidatesWithoutReplacingTranscript() async throws {
        let provider = MockChatCompletionProvider(result: "Keep contextual terms conservative.")
        let processor = OutputProcessor(provider: provider)

        let rawTranscript = "用 Docker Compose 部署 Reddit 和 NextCloud，把 DeepSeq 的结果写进 ReadyTap 文档，再同步 Redis Type 文档，顺便看报表单。"
        let result = try await processor.process(rawTranscript, mode: .promptOutput, scenario: .aiTool)

        XCTAssertEqual(result.rawTranscript, rawTranscript)
        XCTAssertEqual(result.finalText, "Keep contextual terms conservative.")
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].userText.contains("\"Reddit\" may mean \"Redis\""), provider.requests[0].userText)
        XCTAssertTrue(provider.requests[0].userText.contains("\"DeepSeq\" may mean \"DeepSeek\""), provider.requests[0].userText)
        XCTAssertTrue(provider.requests[0].userText.contains("\"ReadyTap\" may mean \"ReadyType\""), provider.requests[0].userText)
        XCTAssertTrue(provider.requests[0].userText.contains("\"Redis Type\" may mean \"ReadyType\""), provider.requests[0].userText)
        XCTAssertTrue(provider.requests[0].userText.contains("\"报表单\" may mean \"报价单\""), provider.requests[0].userText)
        XCTAssertTrue(provider.requests[0].userText.contains("Use these candidates only when the surrounding context clearly supports them"))
    }

    func testAIModeAppliesConservativeFinalTermNormalization() async throws {
        let provider = MockChatCompletionProvider(
            result: "请更新 ReadMe 文档，确认高精度银包和急速识别的代办事项。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "请帮我整理一条产品反馈，更新 read me 文档，确认高精度语音包和极速识别的待办事项",
            mode: .aiCleanup,
            scenario: .document
        )

        XCTAssertEqual(result.finalText, "请更新 README 文档，确认高精度语音包和极速识别的待办事项。")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testAIModeNormalizesTechnicalReleaseChecklistTerms() async throws {
        let provider = MockChatCompletionProvider(
            result: "Reddit Tab现在需要检查GitHub Actions、README、Docker Compose、Redis、Nextcloud、DeepSeek page，确认打包文件和更新日志都没有问题。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "帮我整理一段技术说明，ReadyType 现在需要检查 GitHub Actions、README、Docker Compose、Redis、Nextcloud 和 DeepSeek 的配置，确认打包文件和更新日志都没有问题",
            mode: .aiCleanup,
            scenario: .document
        )

        XCTAssertEqual(
            result.finalText,
            "ReadyType现在需要检查GitHub Actions、README、Docker Compose、Redis、Nextcloud、DeepSeek的配置，确认打包文件和更新日志都没有问题。"
        )
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testMessageCleanupRemovesRecipientInstructionPrefixAndTrailingStopWord() async throws {
        let provider = MockChatCompletionProvider(
            result: "发给李四：报价单第三项费用有问题，先别发给客户。OK。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "发给李四，报价单第三项费用有问题，先别发给客户，OK",
            mode: .aiCleanup,
            scenario: .message
        )

        XCTAssertEqual(result.finalText, "报价单第三项费用有问题，先别发给客户。")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testMessageCleanupRemovesRecipientNameWhenOriginalTranscriptWasSendInstruction() async throws {
        let provider = MockChatCompletionProvider(
            result: "李四，报价单第三项费用有问题，先别发给客户。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "发给李四，报价单第三项费用有问题，先别发给客户，OK",
            mode: .aiCleanup,
            scenario: .message
        )

        XCTAssertEqual(result.finalText, "报价单第三项费用有问题，先别发给客户。")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testMessageCleanupRemovesRecipientInstructionWithoutSeparator() async throws {
        let provider = MockChatCompletionProvider(
            result: "发给李四报价单第三项费用有问题，先别发给客户。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "发给李四，报价单第三项费用有问题，先别发给客户，OK",
            mode: .aiCleanup,
            scenario: .message
        )

        XCTAssertEqual(result.finalText, "报价单第三项费用有问题，先别发给客户。")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testFinalCleanupDoesNotRemoveContentEndingWithCompletionWord() async throws {
        let provider = MockChatCompletionProvider(
            result: "任务已完成。"
        )
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "任务已经完成",
            mode: .aiCleanup,
            scenario: .generic
        )

        XCTAssertEqual(result.finalText, "任务已完成。")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
    }

    func testAIModeUsesCurrentUserVocabularyTermCandidatesForEachRequest() async throws {
        let firstProvider = MockChatCompletionProvider(result: "first")
        let secondProvider = MockChatCompletionProvider(result: "second")
        var providers = [firstProvider, secondProvider]
        var entries: [UserVocabularyEntry] = []
        let processor = OutputProcessor(
            providerFactory: {
                providers.removeFirst()
            },
            termCorrectionServiceProvider: {
                TermCorrectionService(dictionary: SmartTermDictionary.readyTypeDefault.mergingUserVocabulary(entries))
            }
        )

        _ = try await processor.process("同步到 ready wod", mode: .aiCleanup, scenario: .message)
        entries = [
            UserVocabularyEntry(value: "ReadyWOD", kind: .project, aliases: ["ready wod"])
        ]
        _ = try await processor.process("同步到 ready wod", mode: .aiCleanup, scenario: .message)

        XCTAssertFalse(firstProvider.requests[0].userText.contains("\"ready wod\" may mean \"ReadyWOD\""))
        XCTAssertTrue(secondProvider.requests[0].userText.contains("\"ready wod\" may mean \"ReadyWOD\""))
    }

    func testAIModeUsesConfirmedVocabularyTermCandidates() async throws {
        let provider = MockChatCompletionProvider(result: "ReadyType 的更新日志已经同步。")
        let entries = [
            UserVocabularyEntry(
                value: "ReadyType",
                kind: .product,
                aliases: ["Reddit Tab"],
                scopes: [.technical],
                source: .confirmedSuggestion,
                confidence: 0.88,
                confirmedCount: 2
            )
        ]
        let processor = OutputProcessor(
            providerFactory: {
                provider
            },
            termCorrectionServiceProvider: {
                TermCorrectionService(dictionary: SmartTermDictionary.readyTypeDefault.mergingUserVocabulary(entries))
            }
        )

        _ = try await processor.process(
            "请整理 Reddit Tab 的更新日志和 GitHub Actions",
            mode: .aiCleanup,
            scenario: .document
        )

        XCTAssertTrue(provider.requests[0].userText.contains("\"Reddit Tab\" may mean \"ReadyType\""))
    }

    func testAIModeScopesTechnicalReadyTypeVariantsToTechnicalContexts() async throws {
        let documentProvider = MockChatCompletionProvider(result: "检查 ReadyType 的 README。")
        let chatProvider = MockChatCompletionProvider(result: "我看到 Reddit Type 的帖子。")
        var providers = [documentProvider, chatProvider]
        let processor = OutputProcessor(providerFactory: {
            providers.removeFirst()
        })

        _ = try await processor.process(
            "请检查 Reddit Type 的 README 和 GitHub Actions 更新日志",
            mode: .aiCleanup,
            scenario: .document
        )
        _ = try await processor.process(
            "今天看到 Reddit Type 的帖子",
            mode: .aiCleanup,
            scenario: .message
        )

        XCTAssertTrue(documentProvider.requests[0].userText.contains("\"Reddit Type\" may mean \"ReadyType\""))
        XCTAssertFalse(chatProvider.requests[0].userText.contains("\"Reddit Type\" may mean \"ReadyType\""))
    }

    func testPromptOutputUsesProviderWithPromptWritingPrompt() async throws {
        let provider = MockChatCompletionProvider(result: "Write a concise project update.")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process("帮我写个项目更新", mode: .promptOutput, scenario: .aiTool)

        XCTAssertEqual(result.finalText, "Write a concise project update.")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("AI assistant"))
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("constraints"))
    }

    func testTranslationModeUsesProviderWithTranslationPrompt() async throws {
        let provider = MockChatCompletionProvider(result: "Please prepare the materials before tomorrow's meeting.")
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process("请提前准备明天会议要用的材料", mode: .translationToEnglish, scenario: .message)

        XCTAssertEqual(result.finalText, "Please prepare the materials before tomorrow's meeting.")
        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback)
        XCTAssertEqual(provider.requests.count, 1)
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("natural English"))
        XCTAssertTrue(provider.requests[0].systemPrompt.contains("chat message"))
        XCTAssertEqual(provider.requests[0].userText, "请提前准备明天会议要用的材料")
    }

    func testAIModeFallsBackToRawTranscriptWhenProviderFails() async throws {
        let provider = MockChatCompletionProvider(error: ReadyTypeError.deepSeekTimeout)
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process("keep my original words", mode: .aiCleanup)

        XCTAssertEqual(result.finalText, "keep my original words")
        XCTAssertTrue(result.usedAI)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(result.warning, .deepSeekTimeout)
    }

    func testAIModeThrowsWhenFallbackWouldPasteInstructionText() async {
        let provider = MockChatCompletionProvider(error: ReadyTypeError.deepSeekTimeout)
        let processor = OutputProcessor(provider: provider)

        do {
            _ = try await processor.process(
                "写一封简短邮件给测试同事说明今天已经完成43条语音样本复测",
                mode: .aiCleanup,
                scenario: .email
            )
            XCTFail("Expected DeepSeek timeout to stop unsafe instruction fallback")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .deepSeekTimeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslationModeThrowsInsteadOfPastingSourceTextWhenProviderFails() async {
        let provider = MockChatCompletionProvider(error: ReadyTypeError.deepSeekTimeout)
        let processor = OutputProcessor(provider: provider)

        do {
            _ = try await processor.process(
                "今天已经完成复测",
                mode: .translationToEnglish,
                scenario: .generic
            )
            XCTFail("Expected translation failure to stop unsafe source-language fallback")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .deepSeekTimeout)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAIModeFallbackAppliesLocalTermProtectionWhenProviderFails() async throws {
        let provider = MockChatCompletionProvider(error: ReadyTypeError.deepSeekTimeout)
        let processor = OutputProcessor(provider: provider)

        let result = try await processor.process(
            "产品反馈更新Redmi文档确认高精度语音包急速识别代办事项和大小写这些固定词都不要写错",
            mode: .aiCleanup,
            scenario: .document
        )

        XCTAssertEqual(result.rawTranscript, "产品反馈更新Redmi文档确认高精度语音包急速识别代办事项和大小写这些固定词都不要写错")
        XCTAssertEqual(result.finalText, "产品反馈更新README文档确认高精度语音包极速识别待办事项和大小写这些固定词都不要写错")
        XCTAssertTrue(result.usedAI)
        XCTAssertTrue(result.usedFallback)
        XCTAssertEqual(result.warning, .deepSeekTimeout)
    }

    func testEmptyTranscriptThrowsBeforeProviderCall() async {
        let provider = MockChatCompletionProvider(result: "should not be used")
        let processor = OutputProcessor(provider: provider)

        do {
            _ = try await processor.process("   ", mode: .aiCleanup)
            XCTFail("Expected transcriptionEmpty error")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .transcriptionEmpty)
            XCTAssertEqual(provider.requests.count, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAIModeUsesCurrentProviderFactoryForEachRequest() async throws {
        let firstProvider = MockChatCompletionProvider(result: "first")
        let secondProvider = MockChatCompletionProvider(result: "second")
        var providers = [firstProvider, secondProvider]
        let processor = OutputProcessor(providerFactory: {
            providers.removeFirst()
        })

        let first = try await processor.process("one", mode: .aiCleanup)
        let second = try await processor.process("two", mode: .aiCleanup)

        XCTAssertEqual(first.finalText, "first")
        XCTAssertEqual(second.finalText, "second")
        XCTAssertEqual(firstProvider.requests.map(\.userText), ["one"])
        XCTAssertEqual(secondProvider.requests.map(\.userText), ["two"])
    }
}

private final class MockChatCompletionProvider: ChatCompletionProvider {
    struct Request {
        let systemPrompt: String
        let userText: String
    }

    private let result: String?
    private let error: Error?
    private(set) var requests: [Request] = []

    init(result: String) {
        self.result = result
        self.error = nil
    }

    init(error: Error) {
        self.result = nil
        self.error = error
    }

    func complete(systemPrompt: String, userText: String) async throws -> String {
        requests.append(Request(systemPrompt: systemPrompt, userText: userText))

        if let error {
            throw error
        }

        return result ?? ""
    }
}
