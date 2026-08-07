import Foundation

struct AnthropicProvider: LLMProvider {
    let name = "Anthropic"
    private let apiKey: String
    private let model: String

    init?(environment: [String: String]) {
        guard let apiKey = environment["ANTHROPIC_API_KEY"] else { return nil }
        self.apiKey = apiKey
        self.model = environment["ANTHROPIC_MODEL"] ?? "claude-sonnet-4-5"
    }

    func generateSuggestions(prompt: String) async throws -> [SuggestionResult] {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            AnthropicRequest(model: model, maxTokens: 2048, messages: [.init(role: "user", content: prompt)])
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMProviderError.requestFailed("Anthropic HTTP \(code): \(body.prefix(300))")
        }
        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.map(\.text).joined()
        return try CloudJSONExtraction.parseSuggestions(from: text)
    }
}

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
    let content: [ContentBlock]
}
