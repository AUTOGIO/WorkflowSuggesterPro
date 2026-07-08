import Foundation

enum AutomationScriptWriterError: Error, CustomStringConvertible {
    case noApplicationSupportDirectory

    var description: String {
        "Could not resolve the user's Application Support directory."
    }
}

struct AutomationScriptWriter: Sendable {
    private let outputDirectory: URL

    init() throws {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AutomationScriptWriterError.noApplicationSupportDirectory
        }
        outputDirectory = appSupport
            .appendingPathComponent("WorkflowSuggesterPro", isDirectory: true)
            .appendingPathComponent("GeneratedAutomations", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func write(_ suggestions: [SuggestionResult], timestamp: Date) throws -> [URL] {
        let stamp = Self.timestampFormatter.string(from: timestamp)
        var writtenURLs: [URL] = []
        for (index, suggestion) in suggestions.enumerated() {
            let filename = "\(stamp)-\(index)-\(Self.slugify(suggestion.title)).sh"
            let fileURL = outputDirectory.appendingPathComponent(filename)
            try Self.scriptContents(for: suggestion).write(to: fileURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fileURL.path)
            writtenURLs.append(fileURL)
        }
        return writtenURLs
    }

    private static func scriptContents(for suggestion: SuggestionResult) -> String {
        let implementationLines = suggestion.implementation
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "# \($0)" }
            .joined(separator: "\n")
        return """
        #!/bin/sh
        # \(suggestion.title)
        #
        # Rationale: \(suggestion.rationale)
        # Estimated savings: \(suggestion.savings)
        #
        # Implementation notes (review before running):
        \(implementationLines)
        """
    }

    private static func slugify(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let dashed = title.lowercased().unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(dashed).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
        return collapsed.isEmpty ? "automation" : collapsed
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        return formatter
    }()
}
