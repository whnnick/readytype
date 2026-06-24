import XCTest
@testable import ReadyType

@MainActor
final class APIConnectionTesterTests: XCTestCase {
    func testMissingAPIKeyDoesNotCreateProvider() async {
        var didCreateProvider = false
        let tester = APIConnectionTester { _, _ in
            didCreateProvider = true
            return MockConnectionProvider(result: .success("OK"))
        }

        let state = await tester.testConnection(
            baseURL: URL(string: "https://example.test")!,
            model: "deepseek-chat",
            apiKey: "   "
        )

        XCTAssertEqual(state.status, .missingKey)
        XCTAssertFalse(didCreateProvider)
    }

    func testSuccessReportsModelAndLatency() async {
        var dates = [
            Date(timeIntervalSince1970: 100),
            Date(timeIntervalSince1970: 100.245)
        ]
        let tester = APIConnectionTester(
            providerFactory: { configuration, apiKey in
                XCTAssertEqual(configuration.model, "deepseek-chat")
                XCTAssertEqual(apiKey, "test-key")
                return MockConnectionProvider(result: .success("OK"))
            },
            clock: { dates.removeFirst() }
        )

        let state = await tester.testConnection(
            baseURL: URL(string: "https://example.test")!,
            model: "deepseek-chat",
            apiKey: "test-key"
        )

        XCTAssertEqual(state.status, .success)
        XCTAssertEqual(state.model, "deepseek-chat")
        XCTAssertEqual(state.latencyMilliseconds, 245)
        XCTAssertEqual(state.displayDetail, "deepseek-chat / 245 ms")
    }

    func testUsesConfiguredTimeoutForConnectionRequest() async {
        let tester = APIConnectionTester(
            providerFactory: { configuration, _ in
                XCTAssertEqual(configuration.timeoutSeconds, 1.5)
                return MockConnectionProvider(result: .success("OK"))
            },
            timeoutSeconds: 1.5
        )

        let state = await tester.testConnection(
            baseURL: URL(string: "https://example.test")!,
            model: "deepseek-chat",
            apiKey: "test-key"
        )

        XCTAssertEqual(state.status, .success)
    }

    func testMapsReadyTypeErrorsToUserFacingStates() async {
        let cases: [(ReadyTypeError, APIConnectionTestStatus)] = [
            (.deepSeekAuthenticationFailed, .authenticationFailed),
            (.deepSeekModelError("HTTP 404"), .modelUnavailable),
            (.deepSeekRateLimited, .unknownFailure),
            (.deepSeekServiceUnavailable(503), .networkFailed),
            (.deepSeekBaseURLUnreachable, .networkFailed),
            (.deepSeekTimeout, .timeout),
            (.deepSeekUnexpectedResponse, .unknownFailure)
        ]

        for (error, expectedStatus) in cases {
            let tester = APIConnectionTester { _, _ in
                MockConnectionProvider(result: .failure(error))
            }

            let state = await tester.testConnection(
                baseURL: URL(string: "https://example.test")!,
                model: "deepseek-chat",
                apiKey: "test-key"
            )

            XCTAssertEqual(state.status, expectedStatus)
        }
    }

    func testRateLimitAndServiceErrorsDoNotLookLikeModelFailures() async {
        let cases: [ReadyTypeError] = [
            .deepSeekRateLimited,
            .deepSeekServiceUnavailable(503),
            .deepSeekUnexpectedResponse
        ]

        for error in cases {
            let tester = APIConnectionTester { _, _ in
                MockConnectionProvider(result: .failure(error))
            }

            let state = await tester.testConnection(
                baseURL: URL(string: "https://example.test")!,
                model: "deepseek-chat",
                apiKey: "test-key"
            )

            XCTAssertNotEqual(state.status, .modelUnavailable)
            XCTAssertFalse(state.displayDetail.contains("模型名"), state.displayDetail)
        }
    }
}

private final class MockConnectionProvider: ChatCompletionProvider {
    let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func complete(systemPrompt: String, userText: String) async throws -> String {
        XCTAssertEqual(systemPrompt, "You are a connection test. Reply with OK only.")
        XCTAssertEqual(userText, "请只回复 OK")
        return try result.get()
    }
}
