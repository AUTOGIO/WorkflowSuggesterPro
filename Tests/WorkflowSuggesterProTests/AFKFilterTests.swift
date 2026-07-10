import Foundation
import Testing
@testable import WorkflowSuggesterCore

private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

private func windowEvent(at offset: TimeInterval, duration: Double = 60) -> AWEvent {
    AWEvent(
        id: nil,
        timestamp: epoch.addingTimeInterval(offset),
        duration: duration,
        data: ["app": .string("Xcode"), "title": .string("Test")]
    )
}

private func afkEvent(status: String, at offset: TimeInterval, duration: Double) -> AWEvent {
    AWEvent(
        id: nil,
        timestamp: epoch.addingTimeInterval(offset),
        duration: duration,
        data: ["status": .string(status)]
    )
}

@Test func keepsWindowEventsOverlappingNotAFKPeriods() throws {
    // not-afk from 0-100; window event at 10-70 fully inside it.
    let windowEvents = [windowEvent(at: 10, duration: 60)]
    let afkEvents = [afkEvent(status: "not-afk", at: 0, duration: 100)]

    let result = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)

    #expect(result.count == 1)
}

@Test func dropsWindowEventsDuringAFKPeriods() throws {
    // afk 0-100, not-afk 200-300 (elsewhere, so there IS usable not-afk signal). Window
    // event at 10-70 falls only within the afk period, so it should be dropped.
    let windowEvents = [windowEvent(at: 10, duration: 60)]
    let afkEvents = [
        afkEvent(status: "afk", at: 0, duration: 100),
        afkEvent(status: "not-afk", at: 200, duration: 100),
    ]

    let result = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)

    #expect(result.isEmpty)
}

@Test func keepsWindowEventPartiallyOverlappingNotAFK() throws {
    // not-afk from 100-200; window event at 90-110 partially overlaps.
    let windowEvents = [windowEvent(at: 90, duration: 20)]
    let afkEvents = [afkEvent(status: "not-afk", at: 100, duration: 100)]

    let result = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)

    #expect(result.count == 1)
}

@Test func passesEventsThroughUnfilteredWhenNoAFKDataAvailable() throws {
    let windowEvents = [windowEvent(at: 0), windowEvent(at: 100)]

    let result = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: [])

    #expect(result.count == 2)
}

@Test func passesEventsThroughUnfilteredWhenOnlyAFKStatusRecorded() throws {
    // Only "afk" status events, no "not-afk" ones — treat as no usable signal rather than
    // filtering everything out.
    let windowEvents = [windowEvent(at: 0), windowEvent(at: 100)]
    let afkEvents = [afkEvent(status: "afk", at: 0, duration: 1000)]

    let result = AFKFilter().filterToActive(windowEvents: windowEvents, afkEvents: afkEvents)

    #expect(result.count == 2)
}
