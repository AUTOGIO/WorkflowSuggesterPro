import FoundationModels

@Generable
struct SuggestionResult: Sendable {
    let title: String
    let rationale: String
    let implementation: String
    @Guide(.anyOf(["High", "Medium", "Low"]))
    let savings: String
}

/// Wrapper for the on-device path. `[SuggestionResult].self` (array-of-Generable) as the
/// top-level generating type was measured to consume ~7900 tokens of fixed schema/grammar
/// overhead against the model's 8192-token window — with the actual prompt at only 286
/// tokens, that overhead alone nearly exhausted the context. A single wrapper `Generable`
/// with an array property is the workaround to test/use instead of a top-level array.
@Generable
struct SuggestionList: Sendable {
    let suggestions: [SuggestionResult]
}
