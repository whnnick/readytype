import XCTest
@testable import ReadyType

@MainActor
final class RealDeepSeekOutputAcceptanceTests: XCTestCase {
    func testChineseSpeechCanBecomeEnglishEmail() async throws {
        let processor = try makeRealProcessor()

        let result = try await processor.process(
            "我想给张三发一封邮件，告诉他项目这周可能会晚两天，原因是设计稿还没有完全确认，明天下午三点需要再沟通一次。提醒他提前准备素材，并带上预算表。请用一二三换行，最后加上谢谢。",
            mode: .translationToEnglish,
            scenario: .email
        )

        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback, String(describing: result.warning))
        XCTAssertFalse(result.finalText.removingKnownChineseNames.containsCJKCharacters, result.finalText)
        XCTAssertTrue(
            result.finalText.localizedCaseInsensitiveContains("Zhang") || result.finalText.contains("张三"),
            result.finalText
        )
        XCTAssertTrue(result.finalText.localizedCaseInsensitiveContains("materials"), result.finalText)
        XCTAssertTrue(result.finalText.localizedCaseInsensitiveContains("budget"), result.finalText)
        XCTAssertGreaterThanOrEqual(result.finalText.nonEmptyLineCount, 3, result.finalText)
    }

    func testChineseSpeechCanBecomeEnglishChatMessage() async throws {
        let processor = try makeRealProcessor()

        let result = try await processor.process(
            "帮我发个消息给李四，说明我今天晚点到，大概六点半，麻烦他先开始会议。",
            mode: .translationToEnglish,
            scenario: .message
        )

        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback, String(describing: result.warning))
        XCTAssertFalse(result.finalText.containsCJKCharacters, result.finalText)
        XCTAssertTrue(result.finalText.localizedCaseInsensitiveContains("meeting"), result.finalText)
        XCTAssertLessThanOrEqual(result.finalText.nonEmptyLineCount, 4, result.finalText)
    }

    func testPersonalChatCleanupDoesNotAddOverPoliteWechatTone() async throws {
        let processor = try makeRealProcessor()

        let result = try await processor.process(
            "发给王嵩，我刚把高级服务器的流量给你重置了，我算了一下，到月底咱俩应该还够用，但是你省着点用，别拿来看视频，看视频的话你用那个流量大的。",
            mode: .aiCleanup,
            context: OutputContext(scenario: .message, chatTone: .personal)
        )

        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback, String(describing: result.warning))
        XCTAssertTrue(result.finalText.contains("高级服务器"), result.finalText)
        XCTAssertTrue(result.finalText.contains("视频"), result.finalText)
        XCTAssertFalse(result.finalText.containsOverPoliteChineseChatPhrases, result.finalText)
        XCTAssertLessThanOrEqual(result.finalText.nonEmptyLineCount, 3, result.finalText)
    }

    func testWorkChatCleanupStaysConciseWithoutEmailFormat() async throws {
        let processor = try makeRealProcessor()

        let result = try await processor.process(
            "发到飞书项目群，设计稿今天还没完全确认，进度可能会晚两天，明天下午三点我们再对一次，请提前把素材和预算表准备好。",
            mode: .aiCleanup,
            context: OutputContext(scenario: .message, chatTone: .work)
        )

        XCTAssertTrue(result.usedAI)
        XCTAssertFalse(result.usedFallback, String(describing: result.warning))
        XCTAssertTrue(result.finalText.contains("设计稿"), result.finalText)
        XCTAssertTrue(result.finalText.contains("预算表"), result.finalText)
        XCTAssertFalse(result.finalText.containsEmailLikeChinesePhrases, result.finalText)
        XCTAssertLessThanOrEqual(result.finalText.nonEmptyLineCount, 4, result.finalText)
    }

    private func makeRealProcessor() throws -> OutputProcessor {
        guard ProcessInfo.processInfo.environment["READYTYPE_RUN_REAL_DEEPSEEK_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Set READYTYPE_RUN_REAL_DEEPSEEK_ACCEPTANCE=1 to run real DeepSeek output acceptance tests.")
        }

        let apiKey = try apiKeyForAcceptance()
        let settings = SettingsStore().load()
        let provider = DeepSeekProvider(
            configuration: DeepSeekConfiguration(
                baseURL: settings.deepSeekBaseURL,
                endpointPath: DeepSeekConfiguration.default.endpointPath,
                model: settings.deepSeekModel,
                timeoutSeconds: DeepSeekConfiguration.default.timeoutSeconds
            ),
            apiKey: apiKey
        )

        return OutputProcessor(provider: provider)
    }

    private func apiKeyForAcceptance() throws -> String {
        if let apiKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !apiKey.isEmpty {
            return apiKey
        }

        guard let apiKey = try KeychainService().loadAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !apiKey.isEmpty
        else {
            throw XCTSkip("Set DEEPSEEK_API_KEY or save a ReadyType DeepSeek API key before running real acceptance tests.")
        }

        return apiKey
    }
}

private extension String {
    var containsCJKCharacters: Bool {
        unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF:
                return true
            default:
                return false
            }
        }
    }

    var nonEmptyLineCount: Int {
        split(whereSeparator: \.isNewline)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }

    var removingKnownChineseNames: String {
        replacingOccurrences(of: "张三", with: "")
            .replacingOccurrences(of: "李四", with: "")
            .replacingOccurrences(of: "王嵩", with: "")
    }

    var containsOverPoliteChineseChatPhrases: Bool {
        [
            "您好",
            "请您",
            "谢谢",
            "感谢",
            "辛苦了",
            "祝好",
            "此致",
            "敬礼"
        ].contains { contains($0) }
    }

    var containsEmailLikeChinesePhrases: Bool {
        [
            "主题：",
            "主题:",
            "尊敬的",
            "您好",
            "此致",
            "敬礼",
            "祝好"
        ].contains { contains($0) }
    }
}
