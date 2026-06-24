import Foundation

final class DeepSeekProvider: ChatCompletionProvider {
    private let configuration: DeepSeekConfiguration
    private let apiKey: String
    private let session: URLSession

    init(
        configuration: DeepSeekConfiguration = .default,
        apiKey: String,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.session = session
    }

    func complete(systemPrompt: String, userText: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReadyTypeError.deepSeekAPIKeyMissing
        }

        let url = configuration.baseURL.appending(path: configuration.endpointPath)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            DeepSeekChatRequest(
                model: configuration.model,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userText)
                ],
                temperature: 0.2
            )
        )

        let responseData: Data
        let urlResponse: URLResponse

        do {
            (responseData, urlResponse) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw ReadyTypeError.deepSeekTimeout
        } catch {
            throw ReadyTypeError.deepSeekBaseURLUnreachable
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw ReadyTypeError.deepSeekUnexpectedResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: responseData)
            guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty
            else {
                throw ReadyTypeError.deepSeekUnexpectedResponse
            }
            return content
        case 401, 403:
            throw ReadyTypeError.deepSeekAuthenticationFailed
        case 400, 404, 422:
            throw ReadyTypeError.deepSeekModelError("HTTP \(httpResponse.statusCode)")
        case 429:
            throw ReadyTypeError.deepSeekRateLimited
        case 500..<600:
            throw ReadyTypeError.deepSeekServiceUnavailable(httpResponse.statusCode)
        default:
            throw ReadyTypeError.deepSeekUnexpectedResponse
        }
    }
}

struct DeepSeekConfiguration: Equatable {
    var baseURL: URL
    var endpointPath: String
    var model: String
    var timeoutSeconds: TimeInterval

    static let `default` = DeepSeekConfiguration(
        baseURL: URL(string: "https://api.deepseek.com")!,
        endpointPath: "/chat/completions",
        model: "deepseek-v4-flash",
        timeoutSeconds: 12
    )
}

private struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [Message]
    let temperature: Double

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct DeepSeekChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String
    }
}
