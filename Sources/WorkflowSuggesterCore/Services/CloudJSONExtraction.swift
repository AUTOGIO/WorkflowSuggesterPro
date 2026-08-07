import Foundation

enum CloudJSONExtraction {
    /// Cloud models are asked to respond with only a JSON array, but they don't always
    /// obey — strip markdown fences and extract the first balanced `[...]` block.
    static func parseSuggestions(from text: String) throws -> [SuggestionResult] {
        let normalized = stripMarkdownCodeFences(from: text)
        guard let jsonSlice = extractJSONArray(from: normalized) else {
            throw LLMProviderError.invalidResponse("No JSON array found in model output: \(text.prefix(200))")
        }

        let data = Data(jsonSlice.utf8)
        let cloudResults = try JSONDecoder().decode([CloudSuggestionResult].self, from: data)
        return cloudResults.map { $0.toSuggestionResult() }
    }

    static func isJSONParseFailure(_ error: Error) -> Bool {
        if error is DecodingError { return true }
        if case LLMProviderError.invalidResponse = error { return true }
        return false
    }

    private static func stripMarkdownCodeFences(from text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.hasPrefix("```") {
            result = String(result.drop(while: { $0 != "\n" }).dropFirst())
            if let closingFence = result.range(of: "\n```", options: .backwards) {
                result = String(result[..<closingFence.lowerBound])
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractJSONArray(from text: String) -> String? {
        guard let start = text.firstIndex(of: "[") else { return nil }

        var depth = 0
        var inString = false
        var escaped = false

        for index in text.indices[start...] {
            let character = text[index]
            if escaped {
                escaped = false
                continue
            }
            if inString {
                if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            switch character {
            case "\"":
                inString = true
            case "[":
                depth += 1
            case "]":
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            default:
                break
            }
        }

        return nil
    }
}
