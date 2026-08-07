import Foundation
import Testing
@testable import WorkflowSuggesterCore

@Test func parsesValidJSONArray() throws {
    let json = """
    [{"title":"Auto-open Xcode","rationale":"Opens project on login","implementation":"open -a Xcode ~/proj","savings":"High"}]
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: json)

    #expect(results.count == 1)
    #expect(results[0].title == "Auto-open Xcode")
    #expect(results[0].savings == "High")
}

@Test func parsesJSONWrappedInPreamble() throws {
    let text = """
    Here are the suggestions:
    [{"title":"T","rationale":"R","implementation":"I","savings":"medium"}]
    Hope this helps!
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: text)

    #expect(results.count == 1)
    #expect(results[0].savings == "Medium")
}

@Test func parsesMultipleSuggestions() throws {
    let json = """
    [
      {"title":"A","rationale":"Ra","implementation":"Ia","savings":"High"},
      {"title":"B","rationale":"Rb","implementation":"Ib","savings":"Low"}
    ]
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: json)

    #expect(results.count == 2)
    #expect(results[0].title == "A")
    #expect(results[1].savings == "Low")
}

@Test func throwsOnMissingJSONArray() throws {
    #expect(throws: (any Error).self) {
        try CloudJSONExtraction.parseSuggestions(from: "No JSON here at all")
    }
}

@Test func throwsOnMalformedJSON() throws {
    #expect(throws: (any Error).self) {
        try CloudJSONExtraction.parseSuggestions(from: "[not valid json]")
    }
}

@Test func parsesJSONWrappedInMarkdownFence() throws {
    let text = """
    ```json
    [{"title":"T","rationale":"R","implementation":"open -a Xcode","savings":"High"}]
    ```
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: text)

    #expect(results.count == 1)
    #expect(results[0].implementation == "open -a Xcode")
}

@Test func parsesJSONArrayWithTrailingTextAfterClosingBracket() throws {
    let text = """
    [{"title":"T","rationale":"R","implementation":"open -a Xcode","savings":"High"}]
    Let me know if you want more.
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: text)

    #expect(results.count == 1)
    #expect(results[0].title == "T")
}

@Test func parsesImplementationWithEscapedQuotes() throws {
    let json = """
    [{"title":"Open Finder","rationale":"R","implementation":"osascript -e 'tell application \\"Finder\\" to activate'","savings":"Medium"}]
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: json)

    #expect(results.count == 1)
    #expect(results[0].implementation.contains("Finder"))
}

@Test func normalizesSavingsValues() throws {
    let json = """
    [
      {"title":"A","rationale":"R","implementation":"I","savings":"high"},
      {"title":"B","rationale":"R","implementation":"I","savings":"low"},
      {"title":"C","rationale":"R","implementation":"I","savings":"whatever"}
    ]
    """
    let results = try CloudJSONExtraction.parseSuggestions(from: json)

    #expect(results[0].savings == "High")
    #expect(results[1].savings == "Low")
    #expect(results[2].savings == "Medium")
}
