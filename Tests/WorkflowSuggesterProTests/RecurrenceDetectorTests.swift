import Foundation
import Testing
@testable import WorkflowSuggesterPro

private func makeEvent(app: String, title: String, duration: Double = 60, at offset: TimeInterval = 0) -> AWEvent {
    AWEvent(
        id: nil,
        timestamp: Date(timeIntervalSince1970: 1_800_000_000 + offset),
        duration: duration,
        data: ["app": .string(app), "title": .string(title)]
    )
}

@Test func groupsByAppAndTitleAndFiltersByThreshold() throws {
    let events = [
        makeEvent(app: "Xcode", title: "WorkflowSuggesterPro", at: 0),
        makeEvent(app: "Xcode", title: "WorkflowSuggesterPro", at: 1),
        makeEvent(app: "Xcode", title: "WorkflowSuggesterPro", at: 2),
        makeEvent(app: "Xcode", title: "WorkflowSuggesterPro", at: 3),
        makeEvent(app: "Finder", title: "Desktop", at: 4), // below threshold
        makeEvent(app: "Xcode", title: "OtherProject", at: 5), // different title, below threshold
    ]

    let result = RecurrenceDetector().detect(events: events, minOccurrences: 4)

    #expect(result.count == 1)
    #expect(result.first?.app == "Xcode")
    #expect(result.first?.title == "WorkflowSuggesterPro")
    #expect(result.first?.occurrences == 4)
    #expect(result.first?.totalDuration == 240)
}

@Test func returnsEmptyWhenNothingMeetsThreshold() throws {
    let events = [
        makeEvent(app: "Finder", title: "Desktop"),
        makeEvent(app: "Safari", title: "Inbox"),
    ]

    let result = RecurrenceDetector().detect(events: events, minOccurrences: 4)

    #expect(result.isEmpty)
}

@Test func skipsEventsMissingAppOrTitle() throws {
    let malformed = AWEvent(id: nil, timestamp: Date(), duration: 10, data: ["app": .string("Finder")])
    let events = Array(repeating: malformed, count: 5)

    let result = RecurrenceDetector().detect(events: events, minOccurrences: 1)

    #expect(result.isEmpty)
}

@Test func skipsEventsWithEmptyAppOrTitle() throws {
    // Real AW data includes noise like Finder/Raycast events with an empty title —
    // these aren't meaningful "recurring workflows" and would otherwise pollute suggestions.
    let events = [
        makeEvent(app: "Finder", title: ""),
        makeEvent(app: "Finder", title: ""),
        makeEvent(app: "Finder", title: ""),
        makeEvent(app: "Finder", title: ""),
        makeEvent(app: "", title: "Raycast"),
        makeEvent(app: "", title: "Raycast"),
        makeEvent(app: "", title: "Raycast"),
        makeEvent(app: "", title: "Raycast"),
    ]

    let result = RecurrenceDetector().detect(events: events, minOccurrences: 4)

    #expect(result.isEmpty)
}

@Test func sortsByOccurrencesDescending() throws {
    let events =
        Array(repeating: makeEvent(app: "A", title: "A"), count: 4) +
        Array(repeating: makeEvent(app: "B", title: "B"), count: 6)

    let result = RecurrenceDetector().detect(events: events, minOccurrences: 4)

    #expect(result.map(\.app) == ["B", "A"])
}
