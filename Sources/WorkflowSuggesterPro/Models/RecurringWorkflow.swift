import Foundation

struct RecurringWorkflow: Sendable, Equatable {
    let app: String
    let title: String
    let occurrences: Int
    let totalDuration: TimeInterval
}
