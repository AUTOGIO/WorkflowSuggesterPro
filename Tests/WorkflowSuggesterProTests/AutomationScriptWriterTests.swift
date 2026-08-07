import Foundation
import Testing
@testable import WorkflowSuggesterCore

@Test func writesScriptFilesAndReturnsURLs() throws {
    let suggestions = [
        SuggestionResult(title: "Open Xcode", rationale: "Saves time", implementation: "open -a Xcode", savings: "High"),
        SuggestionResult(title: "Clean Downloads", rationale: "Tidy up", implementation: "rm ~/Downloads/*.tmp", savings: "Low"),
    ]
    let writer = try AutomationScriptWriter()
    let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    let urls = try writer.write(suggestions, timestamp: timestamp)

    #expect(urls.count == 2)
    for url in urls {
        #expect(url.pathExtension == "sh")
        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.hasPrefix("#!/bin/sh"))

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attributes[.posixPermissions] as? Int
        #expect(permissions == 0o644)

        try FileManager.default.removeItem(at: url)
    }
}

@Test func scriptContainsExecutableImplementation() throws {
    let suggestion = SuggestionResult(
        title: "Test Script",
        rationale: "Testing",
        implementation: "echo hello\necho world",
        savings: "Medium"
    )
    let writer = try AutomationScriptWriter()
    let urls = try writer.write([suggestion], timestamp: Date())

    let contents = try String(contentsOf: urls[0], encoding: .utf8)
    #expect(contents.contains("echo hello"))
    #expect(contents.contains("echo world"))
    #expect(!contents.contains("# echo hello"))
    #expect(contents.contains("# Test Script"))
    #expect(contents.contains("Review this script before running"))

    try FileManager.default.removeItem(at: urls[0])
}

@Test func slugifiesSpecialCharacters() throws {
    let suggestion = SuggestionResult(
        title: "Open Xcode & Build!",
        rationale: "R",
        implementation: "I",
        savings: "High"
    )
    let writer = try AutomationScriptWriter()
    let urls = try writer.write([suggestion], timestamp: Date())

    let filename = urls[0].lastPathComponent
    #expect(filename.contains("open-xcode-build"))
    #expect(!filename.contains("&"))
    #expect(!filename.contains("!"))

    try FileManager.default.removeItem(at: urls[0])
}
