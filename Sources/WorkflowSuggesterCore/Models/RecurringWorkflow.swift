import Foundation

public struct RecurringWorkflow: Sendable, Equatable, Hashable {
    public let app: String
    public let title: String
    public let occurrences: Int
    public let totalDuration: TimeInterval

    public init(app: String, title: String, occurrences: Int, totalDuration: TimeInterval) {
        self.app = app
        self.title = title
        self.occurrences = occurrences
        self.totalDuration = totalDuration
    }
}
