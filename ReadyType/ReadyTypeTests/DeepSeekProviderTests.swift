import XCTest
@testable import ReadyType

@MainActor
final class DeepSeekProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testCompleteSendsChatCompletionRequestAndReturnsMessageContent() async throws {
        let session = makeSession()
        let configuration = DeepSeekConfiguration(
            baseURL: URL(string: "https://example.test")!,
            endpointPath: "/chat/completions",
            model: "deepseek-chat",
            timeoutSeconds: 10
        )
        let provider = DeepSeekProvider(configuration: configuration, apiKey: "test-key", session: session)

        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://example.test/chat/completions")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try self.requestBody(from: request)
            let payload = try JSONDecoder().decode(ChatRequestPayload.self, from: body)
            XCTAssertEqual(payload.model, "deepseek-chat")
            XCTAssertEqual(payload.messages.map(\.role), ["system", "user"])
            XCTAssertEqual(payload.messages.map(\.content), ["system prompt", "raw text"])

            let response = HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = Data(#"{"choices":[{"message":{"content":" Clean output. "}}]}"#.utf8)
            return (response, data)
        }

        let output = try await provider.complete(systemPrompt: "system prompt", userText: "raw text")

        XCTAssertEqual(output, "Clean output.")
    }

    func testCompleteMapsUnauthorizedResponseToAuthenticationError() async {
        let session = makeSession()
        let provider = DeepSeekProvider(
            configuration: DeepSeekConfiguration(
                baseURL: URL(string: "https://example.test")!,
                endpointPath: "/chat/completions",
                model: "deepseek-chat",
                timeoutSeconds: 10
            ),
            apiKey: "bad-key",
            session: session
        )

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await provider.complete(systemPrompt: "system", userText: "text")
            XCTFail("Expected authentication failure")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .deepSeekAuthenticationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCompleteMapsModelStatusOnlyForModelLikeFailures() async {
        await assertHTTPStatus(400, mapsTo: .deepSeekModelError("HTTP 400"))
        await assertHTTPStatus(404, mapsTo: .deepSeekModelError("HTTP 404"))
        await assertHTTPStatus(422, mapsTo: .deepSeekModelError("HTTP 422"))
    }

    func testCompleteDoesNotMapRateLimitOrServerFailuresToModelError() async {
        await assertHTTPStatus(429, mapsTo: .deepSeekRateLimited)
        await assertHTTPStatus(500, mapsTo: .deepSeekServiceUnavailable(500))
        await assertHTTPStatus(503, mapsTo: .deepSeekServiceUnavailable(503))
    }

    func testCompleteRejectsMissingAPIKeyBeforeNetworkRequest() async {
        let session = makeSession()
        let provider = DeepSeekProvider(apiKey: "   ", session: session)
        var didCallNetwork = false
        MockURLProtocol.handler = { request in
            didCallNetwork = true
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        do {
            _ = try await provider.complete(systemPrompt: "system", userText: "text")
            XCTFail("Expected missing API key error")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, .deepSeekAPIKeyMissing)
            XCTAssertFalse(didCallNetwork)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func assertHTTPStatus(_ statusCode: Int, mapsTo expectedError: ReadyTypeError) async {
        let session = makeSession()
        let provider = DeepSeekProvider(
            configuration: DeepSeekConfiguration(
                baseURL: URL(string: "https://example.test")!,
                endpointPath: "/chat/completions",
                model: "deepseek-chat",
                timeoutSeconds: 10
            ),
            apiKey: "test-key",
            session: session
        )

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        do {
            _ = try await provider.complete(systemPrompt: "system", userText: "text")
            XCTFail("Expected HTTP \(statusCode) to throw")
        } catch let error as ReadyTypeError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func requestBody(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw stream.streamError ?? ReadyTypeError.deepSeekUnexpectedResponse
            }
            if read == 0 {
                break
            }
            data.append(buffer, count: read)
        }

        return data
    }
}

private struct ChatRequestPayload: Decodable {
    let model: String
    let messages: [Message]

    struct Message: Decodable {
        let role: String
        let content: String
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: ReadyTypeError.deepSeekUnexpectedResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
