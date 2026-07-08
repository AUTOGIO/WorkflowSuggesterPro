import Foundation

struct RecurrenceDetector: Sendable {
    func detect(events: [AWEvent], minOccurrences: Int) -> [RecurringWorkflow] {
        struct Accumulator {
            var app: String
            var title: String
            var occurrences: Int = 0
            var totalDuration: TimeInterval = 0
        }

        var accumulators: [String: Accumulator] = [:]

        for event in events {
            guard let app = event.data["app"]?.stringValue,
                  let title = event.data["title"]?.stringValue,
                  !app.isEmpty, !title.isEmpty else { continue }
            let key = "\(app)::\(title)"
            var accumulator = accumulators[key] ?? Accumulator(app: app, title: title)
            accumulator.occurrences += 1
            accumulator.totalDuration += event.duration
            accumulators[key] = accumulator
        }

        return accumulators.values
            .filter { $0.occurrences >= minOccurrences }
            .map { RecurringWorkflow(app: $0.app, title: $0.title, occurrences: $0.occurrences, totalDuration: $0.totalDuration) }
            .sorted { $0.occurrences > $1.occurrences }
    }
}
