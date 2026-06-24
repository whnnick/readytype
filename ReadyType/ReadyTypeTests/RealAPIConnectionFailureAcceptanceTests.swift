import XCTest
@testable import ReadyType

@MainActor
final class RealAPIConnectionFailureAcceptanceTests: XCTestCase {
    func testInvalidAPIKeyReportsAuthenticationFailure() async throws {
        try requireRealAPIFailureAcceptance()

        let state = await APIConnectionTester(timeoutSeconds: 8).testConnection(
            baseURL: settings.deepSeekBaseURL,
            model: settings.deepSeekModel,
            apiKey: "readytype-invalid-key-for-acceptance"
        )

        XCTAssertEqual(state.status, .authenticationFailed, state.displayDetail)
    }

    func testInvalidModelReportsModelUnavailable() async throws {
        try requireRealAPIFailureAcceptance()
        let apiKey = try apiKeyForAcceptance()

        let state = await APIConnectionTester(timeoutSeconds: 8).testConnection(
            baseURL: settings.deepSeekBaseURL,
            model: "readytype-nonexistent-model-acceptance",
            apiKey: apiKey
        )

        XCTAssertEqual(state.status, .modelUnavailable, state.displayDetail)
    }

    func testUnreachableBaseURLReportsNetworkFailure() async throws {
        try requireRealAPIFailureAcceptance()

        let state = await APIConnectionTester(timeoutSeconds: 2).testConnection(
            baseURL: URL(string: "http://127.0.0.1:9")!,
            model: settings.deepSeekModel,
            apiKey: "readytype-network-failure-acceptance"
        )

        XCTAssertEqual(state.status, .networkFailed, state.displayDetail)
    }

    func testSlowEndpointReportsTimeout() async throws {
        try requireRealAPIFailureAcceptance()

        guard let baseURLText = ProcessInfo.processInfo.environment["READYTYPE_API_TIMEOUT_BASE_URL"],
              let baseURL = URL(string: baseURLText)
        else {
            throw XCTSkip("Set READYTYPE_API_TIMEOUT_BASE_URL to a local slow HTTP endpoint.")
        }

        let state = await APIConnectionTester(timeoutSeconds: 1).testConnection(
            baseURL: baseURL,
            model: settings.deepSeekModel,
            apiKey: "readytype-timeout-acceptance"
        )

        XCTAssertEqual(state.status, .timeout, state.displayDetail)
    }

    private var settings: AppSettings {
        SettingsStore().load()
    }

    private func requireRealAPIFailureAcceptance() throws {
        guard ProcessInfo.processInfo.environment["READYTYPE_RUN_REAL_API_FAILURE_ACCEPTANCE"] == "1" else {
            throw XCTSkip("Set READYTYPE_RUN_REAL_API_FAILURE_ACCEPTANCE=1 to run real API failure acceptance tests.")
        }
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
            throw XCTSkip("Set DEEPSEEK_API_KEY or save a ReadyType DeepSeek API key before running real API failure acceptance tests.")
        }

        return apiKey
    }
}
