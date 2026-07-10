import Foundation

public struct CloudSuggestionService: Sendable {
    private let environment: [String: String]

    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    public func generateSuggestions(for workflows: [RecurringWorkflow]) async throws -> [SuggestionResult] {
        let provider = try selectProvider()
        let prompt = WorkflowPromptFormatting.jsonPrompt(for: workflows)
        return try await provider.generateSuggestions(prompt: prompt)
    }

    private func selectProvider() throws -> any LLMProvider {
        let anthropic = AnthropicProvider(environment: environment)
        let openAI = OpenAIProvider(environment: environment)

        switch environment["WORKFLOWSUGGESTER_PROVIDER"]?.lowercased() {
        case "anthropic":
            guard let anthropic else { throw LLMProviderError.missingAPIKey("ANTHROPIC_API_KEY") }
            return anthropic
        case "openai":
            guard let openAI else { throw LLMProviderError.missingAPIKey("OPENAI_API_KEY") }
            return openAI
        default:
            if let anthropic { return anthropic }
            if let openAI { return openAI }
            throw LLMProviderError.missingAPIKey("ANTHROPIC_API_KEY or OPENAI_API_KEY")
        }
    }
}
