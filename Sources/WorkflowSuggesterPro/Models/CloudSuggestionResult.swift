import Foundation

/// Plain Codable DTO for parsing cloud LLM JSON output, kept separate from `SuggestionResult`
/// (which is `@Generable`-only, for the guided on-device path) rather than making one type
/// serve both — avoids depending on unverified interaction between the `@Generable` macro's
/// synthesized members and `Codable` synthesis.
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
