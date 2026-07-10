import Foundation

struct OpenAIProvider: LLMProvider {
    let name = "OpenAI"
    private let apiKey: String
    private let model: String

    init?(environment: [String: String]) {
        guard let apiKey = environment["OPENAI_API_KEY"] else { return nil }
        self.apiKey = apiKey
        self.model = environment["OPENAI_MODEL"] ?? "gpt-4o-mini"
    }

    func generateSuggestions(prompt: String) async throws -> [SuggestionResult] {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONEncoder().encode(
            OpenAIRequest(model: model, messages: [.init(role: "user", content: prompt)])
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMProviderError.requestFailed("OpenAI HTTP \(code): \(body.prefix(300))")
        }
        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content else {
            throw LLMProviderError.invalidResponse("No choices in OpenAI response")
        }
        return try CloudJSONExtraction.parseSuggestions(from: text)
    }
}

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }
    let choices: [Choice]
}
