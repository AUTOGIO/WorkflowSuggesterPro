import Foundation
import Testing
@testable import WorkflowSuggesterPro

// Captured verbatim from a live `GET /api/0/buckets/{id}/events` call against a running
// ActivityWatch instance — guards the real risk this project flagged: AW timestamps carry
// 6-digit fractional seconds ("...24.731000+00:00"), which a plain ISO8601DateFormatter
// (no .withFractionalSeconds) fails to parse.
private let liveFixtureJSON = """
[
  {"id": 11, "timestamp": "2026-07-08T20:08:24.731000+00:00", "duration": 286.953, "data": {"title": "Claude", "app": "Claude"}},
  {"id": 10, "timestamp": "2026-07-08T20:08:23.731000+00:00", "duration": 0.999, "data": {"title": "Desktop", "app": "Finder"}}
]
"""

@Test func decodesRealActivityWatchEventShape() throws {
    let data = Data(liveFixtureJSON.utf8)
    let events = try AWDateDecoding.decoder().decode([AWEvent].self, from: data)

    #expect(events.count == 2)
    #expect(events[0].id == 11)
    #expect(events[0].duration == 286.953)
    #expect(events[0].data["app"]?.stringValue == "Claude")
    #expect(events[0].data["title"]?.stringValue == "Claude")
    #expect(events[1].data["app"]?.stringValue == "Finder")

    let expectedTimestamp = ISO8601DateFormatter()
    expectedTimestamp.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let expected = expectedTimestamp.date(from: "2026-07-08T20:08:24.731000+00:00")
    #expect(events[0].timestamp == expected)
}

@Test func plainISO8601FormatterWithoutFractionalSecondsRejectsAWTimestamps() throws {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    #expect(formatter.date(from: "2026-07-08T20:08:24.731000+00:00") == nil)
}
