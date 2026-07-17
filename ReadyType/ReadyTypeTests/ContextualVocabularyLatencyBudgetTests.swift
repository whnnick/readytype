import XCTest
@testable import ReadyType

final class ContextualVocabularyLatencyBudgetTests: XCTestCase {
    func testCandidateGenerationP95StaysUnderFiftyMilliseconds() async {
        let provider = ContextualVocabularyProvider(dictionary: Self.largeDictionary())
        var samples: [Double] = []

        for index in 0..<120 {
            let request = ContextualVocabularyRequest(
                scenario: Self.scenarios[index % Self.scenarios.count],
                frontmostAppBundleIdentifier: Self.bundleIdentifiers[index % Self.bundleIdentifiers.count],
                projectRoot: nil,
                transcriptPrefix: Self.prefixes[index % Self.prefixes.count],
                maximumTerms: 60,
                timeoutMilliseconds: 80
            )

            let started = DispatchTime.now().uptimeNanoseconds
            _ = await provider.terms(for: request)
            let elapsed = DispatchTime.now().uptimeNanoseconds - started
            samples.append(Double(elapsed) / 1_000_000)
        }

        let p95 = Self.percentile(samples, percentile: 0.95)
        print(String(format: "Contextual vocabulary benchmark: samples=%d p95=%.3fms", samples.count, p95))

        XCTAssertLessThan(
            p95,
            Self.candidateP95BudgetMilliseconds,
            "Contextual vocabulary candidate generation P95 must stay under \(Self.candidateP95BudgetMilliseconds)ms."
        )
    }

    func testCandidateGenerationSkipsEnhancementAfterTimeoutBudget() async {
        let provider = ContextualVocabularyProvider(
            dictionary: Self.largeDictionary(),
            artificialDelayNanoseconds: 150_000_000
        )
        let request = ContextualVocabularyRequest(
            scenario: .document,
            frontmostAppBundleIdentifier: "md.obsidian",
            projectRoot: nil,
            transcriptPrefix: "请整理 docker kubernetes deepseek readytype",
            maximumTerms: 60,
            timeoutMilliseconds: 80
        )

        let started = DispatchTime.now().uptimeNanoseconds
        let terms = await provider.terms(for: request)
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000

        print(String(format: "Contextual vocabulary timeout benchmark: elapsed=%.3fms", elapsedMilliseconds))

        XCTAssertEqual(terms, [])
        XCTAssertLessThan(
            elapsedMilliseconds,
            Self.timeoutFallbackBudgetMilliseconds,
            "Contextual vocabulary enhancement should return close to the 80ms timeout budget."
        )
    }

    private static var candidateP95BudgetMilliseconds: Double {
        isRunningOnGitHubActions ? 80 : 50
    }

    private static var timeoutFallbackBudgetMilliseconds: Double {
        isRunningOnGitHubActions ? 300 : 120
    }

    private static var isRunningOnGitHubActions: Bool {
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    }

    private static let scenarios: [OutputScenario] = [
        .message,
        .email,
        .note,
        .aiTool,
        .document,
        .generic
    ]

    private static let bundleIdentifiers = [
        "com.tencent.xinWeChat",
        "com.larksuite.Feishu",
        "com.apple.Safari",
        "com.google.Chrome",
        "com.todesktop.230313mzl4w4u92",
        "com.apple.dt.Xcode",
        "md.obsidian",
        "notion.id"
    ]

    private static let prefixes = [
        "帮我写一封邮件给张三，说明 docker compose 的部署延迟",
        "整理 readytype 1.0.0 的发布计划和 deepseek api 测试",
        "请把 cursor 里的 kubernetes 配置问题整理成给 AI 的提示",
        "明天下午三点沟通预算表和设计稿确认",
        "nextcloud redis postgres 的迁移方案要写清楚风险",
        "记录 crossfit readyplay 的技术词识别问题"
    ]

    private static func largeDictionary() -> SmartTermDictionary {
        let baseTerms = [
            SmartTerm(value: "ReadyType", source: .userDefined, weight: 80),
            SmartTerm(value: "ReadyPlay", source: .userDefined, weight: 70),
            SmartTerm(value: "DeepSeek", source: .builtIn, weight: 50),
            SmartTerm(value: "Docker", source: .builtIn, weight: 45),
            SmartTerm(value: "Kubernetes", source: .builtIn, weight: 45),
            SmartTerm(value: "Nextcloud", source: .projectFile, weight: 42),
            SmartTerm(value: "Redis", source: .packageName, weight: 40),
            SmartTerm(value: "Postgres", source: .packageName, weight: 40),
            SmartTerm(value: "Cursor", source: .builtIn, weight: 38),
            SmartTerm(value: "Xcode", source: .builtIn, weight: 36)
        ]

        let generatedTerms = (0..<5_000).map { index in
            SmartTerm(
                value: "ProjectTerm\(index)",
                source: index.isMultiple(of: 3) ? .trending : .builtIn,
                weight: Double(index % 17)
            )
        }

        return SmartTermDictionary(terms: baseTerms + generatedTerms)
    }

    private static func percentile(_ samples: [Double], percentile: Double) -> Double {
        precondition(!samples.isEmpty)
        let sorted = samples.sorted()
        let index = max(0, min(sorted.count - 1, Int(ceil(Double(sorted.count) * percentile)) - 1))
        return sorted[index]
    }
}
