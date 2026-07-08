import Foundation

struct CloudSuggestionService: Sendable {
    private let environment: [String: String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    func generateSuggestions(for workflows: [RecurringWorkflow]) async throws -> [SuggestionResult] {
        let provider = try selectProvider()
        let prompt = """
        Recurring workflows detected on this Mac from the last 14 days of window-activity history:

        \(WorkflowPromptFormatting.summary(for: workflows))

        \(WorkflowPromptFormatting.instruction)

        Respond with ONLY a JSON array, no markdown code fences, no commentary. Each element must be \
        an object with exactly these string fields: "title", "rationale", "implementation", "savings" \
        (one of "High", "Medium", "Low").
        """
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
