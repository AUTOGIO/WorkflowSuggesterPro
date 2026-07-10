import Foundation

/// Keeps window events that overlap a "not-afk" period — a lightweight, client-side
/// version of AW's own `filter_period_intersect` AQL primitive. Mirrors the pattern from
/// https://docs.activitywatch.net/en/latest/examples/working-with-data.html for combining
/// the window and AFK watchers, without pulling in AQL/query-string parsing for one filter.
///
/// Deliberately doesn't clip event durations to the overlapping sub-interval — it keeps or
/// drops each window event whole. That's coarser than AW's own canonical-events processing,
/// but sufficient for RecurrenceDetector, which only needs occurrence counts and rough
/// totals, not precise durations.
public struct AFKFilter: Sendable {
    public init() {}

    public func filterToActive(windowEvents: [AWEvent], afkEvents: [AWEvent]) -> [AWEvent] {
        let notAFKIntervals: [(start: Date, end: Date)] = afkEvents.compactMap { event in
            guard event.data["status"]?.stringValue == "not-afk" else { return nil }
            return (event.timestamp, event.timestamp.addingTimeInterval(event.duration))
        }

        // No usable AFK data (watcher not running, or nothing but "afk" periods recorded) —
        // pass everything through rather than filtering to zero.
        guard !notAFKIntervals.isEmpty else { return windowEvents }

        return windowEvents.filter { event in
            let eventEnd = event.timestamp.addingTimeInterval(event.duration)
            return notAFKIntervals.contains { start, end in
                event.timestamp < end && start < eventEnd
            }
        }
    }
}
