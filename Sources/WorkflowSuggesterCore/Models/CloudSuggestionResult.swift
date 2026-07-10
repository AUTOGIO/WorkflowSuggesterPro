import Foundation

/// Plain Codable DTO for parsing free-text LLM JSON output (both the cloud providers and,
/// after guided generation was abandoned, the on-device path too — see
/// FoundationModelsSuggestionService), then mapped into the public SuggestionResult.
struct CloudSuggestionResult: Codable, Sendable {
    let title: String
    let rationale: String
    let implementation: String
    let savings: String

    func toSuggestionResult() -> SuggestionResult {
        let normalizedSavings: String
        switch savings.lowercased() {
        case "high": normalizedSavings = "High"
        case "low": normalizedSavings = "Low"
        default: normalizedSavings = "Medium"
        }
        return SuggestionResult(
            title: title,
            rationale: rationale,
            implementation: implementation,
            savings: normalizedSavings
        )
    }
}
