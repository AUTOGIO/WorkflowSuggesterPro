import FoundationModels

@Generable
struct SuggestionResult: Sendable {
    let title: String
    let rationale: String
    let implementation: String
    @Guide(.anyOf(["High", "Medium", "Low"]))
    let savings: String
}
