import Foundation

@MainActor
protocol ChatCompletionProvider: AnyObject {
    func complete(systemPrompt: String, userText: String) async throws -> String
}
