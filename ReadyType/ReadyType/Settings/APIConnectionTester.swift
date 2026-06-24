import Foundation

@MainActor
final class APIConnectionTester {
    typealias ProviderFactory = (DeepSeekConfiguration, String) -> ChatCompletionProvider

    private let providerFactory: ProviderFactory
    private let clock: () -> Date
    private let timeoutSeconds: TimeInterval

    init(
        providerFactory: @escaping ProviderFactory = { configuration, apiKey in
            DeepSeekProvider(configuration: configuration, apiKey: apiKey)
        },
        clock: @escaping () -> Date = Date.init,
        timeoutSeconds: TimeInterval = 12
    ) {
        self.providerFactory = providerFactory
        self.clock = clock
        self.timeoutSeconds = timeoutSeconds
    }

    func testConnection(baseURL: URL, model: String, apiKey: String) async -> APIConnectionTestState {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedAPIKey.isEmpty else {
            return APIConnectionTestState(
                status: .missingKey,
                detail: "请先填写 DeepSeek 密钥，或保存后使用钥匙串里的密钥。",
                model: trimmedModel.isEmpty ? nil : trimmedModel,
                latencyMilliseconds: nil
            )
        }

        let configuration = DeepSeekConfiguration(
            baseURL: baseURL,
            endpointPath: DeepSeekConfiguration.default.endpointPath,
            model: trimmedModel,
            timeoutSeconds: timeoutSeconds
        )
        let provider = providerFactory(configuration, trimmedAPIKey)
        let startedAt = clock()

        do {
            _ = try await provider.complete(
                systemPrompt: "You are a connection test. Reply with OK only.",
                userText: "请只回复 OK"
            )
            return APIConnectionTestState(
                status: .success,
                detail: nil,
                model: trimmedModel,
                latencyMilliseconds: max(0, Int(clock().timeIntervalSince(startedAt) * 1_000))
            )
        } catch let error as ReadyTypeError {
            return mappedState(for: error, model: trimmedModel)
        } catch {
            return APIConnectionTestState(
                status: .unknownFailure,
                detail: "测试失败，请稍后重试。",
                model: trimmedModel,
                latencyMilliseconds: nil
            )
        }
    }

    private func mappedState(for error: ReadyTypeError, model: String) -> APIConnectionTestState {
        switch error {
        case .deepSeekAPIKeyMissing:
            return APIConnectionTestState(
                status: .missingKey,
                detail: "请先填写 DeepSeek 密钥，或保存后使用钥匙串里的密钥。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekAuthenticationFailed:
            return APIConnectionTestState(
                status: .authenticationFailed,
                detail: "请检查 DeepSeek 密钥是否正确，或当前账号是否有访问权限。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekModelError:
            return APIConnectionTestState(
                status: .modelUnavailable,
                detail: "请检查模型名是否正确，或当前账号是否支持该模型。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekRateLimited:
            return APIConnectionTestState(
                status: .unknownFailure,
                detail: "DeepSeek 当前请求受限，请稍后重试或检查账号额度。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekServiceUnavailable:
            return APIConnectionTestState(
                status: .networkFailed,
                detail: "DeepSeek 服务暂时不可用，请稍后重试。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekBaseURLUnreachable:
            return APIConnectionTestState(
                status: .networkFailed,
                detail: "请检查网络、服务地址或代理设置。",
                model: model,
                latencyMilliseconds: nil
            )
        case .deepSeekTimeout:
            return APIConnectionTestState(
                status: .timeout,
                detail: "测试请求超时，请稍后重试。",
                model: model,
                latencyMilliseconds: nil
            )
        default:
            return APIConnectionTestState(
                status: .unknownFailure,
                detail: error.userMessage,
                model: model,
                latencyMilliseconds: nil
            )
        }
    }
}
