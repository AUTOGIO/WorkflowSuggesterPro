import Foundation

protocol LLMProvider: Sendable {
    var name: String { get }
    func generateSuggestions(prompt: String) async throws -> [SuggestionResult]
}

public enum LLMProviderError: Error, CustomStringConvertible {
    case missingAPIKey(String)
    case requestFailed(String)
    case invalidResponse(String)

    public var description: String {
        switch self {
        case .missingAPIKey(let envVar): return "Missing \(envVar) environment variable."
        case .requestFailed(let message): return "Request failed: \(message)"
        case .invalidResponse(let message): return "Invalid response: \(message)"
        }
    }
}
