import Foundation

public struct SuggestionResult: Sendable, Equatable, Hashable {
    public let title: String
    public let rationale: String
    public let implementation: String
    public let savings: String

    public init(title: String, rationale: String, implementation: String, savings: String) {
        self.title = title
        self.rationale = rationale
        self.implementation = implementation
        self.savings = savings
    }
}
