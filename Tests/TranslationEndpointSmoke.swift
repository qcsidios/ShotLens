import Foundation

@main
struct TranslationEndpointSmoke {
    static func main() async throws {
        URLProtocol.registerClass(MockOpenAIProtocol.self)
        defer { URLProtocol.unregisterClass(MockOpenAIProtocol.self) }

        try await assertTranslates(
            endpoint: "https://shotlens-test.local/v1",
            expectedPath: "/v1/chat/completions"
        )
        try await assertTranslates(
            endpoint: "https://shotlens-test.local/v1/",
            expectedPath: "/v1/chat/completions"
        )
        try await assertTranslates(
            endpoint: "https://shotlens-test.local/v1/chat/completions",
            expectedPath: "/v1/chat/completions"
        )
        try await assertTranslates(
            endpoint: "https://shotlens-test.local/v1",
            expectedPath: "/v1/chat/completions",
            assistantContent: "1. 你好\n2. 世界"
        )
        try await assertTranslates(
            endpoint: "https://shotlens-test.local/v1",
            expectedPath: "/v1/chat/completions",
            assistantContent: "0: 你好\n1: 世界"
        )
        try await assertConnectionCheckUsesChatCompletions()

        print("Translation endpoint smoke test passed.")
    }

    private static func assertTranslates(
        endpoint: String,
        expectedPath: String,
        assistantContent: String = "0\t你好\n1\t世界"
    ) async throws {
        MockOpenAIProtocol.reset()
        MockOpenAIProtocol.assistantContent = assistantContent

        let translator = LLMTranslator(settings: TranslationSettings(
            apiEndpoint: endpoint,
            apiKey: "test-key",
            model: "test-model"
        ))

        let result = try await translator.translate(["Hello", "World"], from: "en", to: "zh-Hans")
        guard result == ["你好", "世界"] else {
            throw TestFailure("Unexpected translations for \(endpoint): \(result)")
        }

        guard MockOpenAIProtocol.requestedPaths == [expectedPath] else {
            throw TestFailure("Expected request path \(expectedPath), got \(MockOpenAIProtocol.requestedPaths)")
        }
    }

    private static func assertConnectionCheckUsesChatCompletions() async throws {
        MockOpenAIProtocol.reset()
        MockOpenAIProtocol.chatStatusCode = 200
        MockOpenAIProtocol.modelsStatusCode = 404

        let checker = LLMConnectionChecker(settings: TranslationSettings(
            apiEndpoint: "https://shotlens-test.local/v1",
            apiKey: "test-key",
            model: "test-model"
        ))

        let isAvailable = await checker.isAvailable()
        guard isAvailable else {
            throw TestFailure("Expected chat-completions connection check to pass when /models is unavailable")
        }

        guard MockOpenAIProtocol.requestedPaths == ["/v1/chat/completions"] else {
            throw TestFailure("Expected connection check to use chat completions, got \(MockOpenAIProtocol.requestedPaths)")
        }
    }
}

private final class MockOpenAIProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var paths: [String] = []
    static var assistantContent = "0\t你好\n1\t世界"
    static var chatStatusCode = 200
    static var modelsStatusCode = 200

    static var requestedPaths: [String] {
        lock.lock()
        defer { lock.unlock() }
        return paths
    }

    static func reset() {
        lock.lock()
        paths = []
        assistantContent = "0\t你好\n1\t世界"
        chatStatusCode = 200
        modelsStatusCode = 200
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "shotlens-test.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let content = Self.assistantContent
        Self.lock.lock()
        Self.paths.append(path)
        Self.lock.unlock()

        let statusCode: Int
        if path == "/v1/chat/completions" {
            statusCode = Self.chatStatusCode
        } else if path == "/v1/models" {
            statusCode = Self.modelsStatusCode
        } else {
            statusCode = 404
        }
        let body: String = statusCode == 200
            ? try! String(data: JSONSerialization.data(withJSONObject: [
                "choices": [
                    [
                        "message": [
                            "content": content
                        ]
                    ]
                ]
            ]), encoding: .utf8)!
            : #"{"error":{"message":"not found"}}"#

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
