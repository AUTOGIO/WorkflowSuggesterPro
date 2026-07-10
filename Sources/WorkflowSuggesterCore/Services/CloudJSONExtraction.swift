import Foundation

enum CloudJSONExtraction {
    /// Cloud models are asked to respond with only a JSON array, but they don't always
    /// obey — this defensively slices out the first `[...]` block rather than trusting
    /// the whole response body to be clean JSON.
    static func parseSuggestions(from text: String) throws -> [SuggestionResult] {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end else {
            throw LLMProviderError.invalidResponse("No JSON array found in model output: \(text.prefix(200))")
        }
        let data = Data(text[start...end].utf8)
        let cloudResults = try JSONDecoder().decode([CloudSuggestionResult].self, from: data)
        return cloudResults.map { $0.toSuggestionResult() }
    }
}
