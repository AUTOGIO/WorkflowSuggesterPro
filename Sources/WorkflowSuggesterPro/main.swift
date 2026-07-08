import Foundation

let lookbackDays = 14
let minOccurrences = 4

func run() async {
    do {
        let awService = ActivityWatchService()
        let bucketId = try await awService.discoverWindowBucket()
        let since = Date().addingTimeInterval(-Double(lookbackDays) * 86400)
        let events = try await awService.fetchEvents(bucketId: bucketId, since: since)

        let recurring = RecurrenceDetector().detect(events: events, minOccurrences: minOccurrences)
        guard !recurring.isEmpty else {
            print("No recurring workflows found in the last \(lookbackDays) days (threshold: \(minOccurrences)+ occurrences).")
            return
        }

        print("Found \(recurring.count) recurring workflow(s):")
        for workflow in recurring {
            let minutes = Int(workflow.totalDuration / 60)
            print("  - \(workflow.app) — \"\(workflow.title)\": \(workflow.occurrences)x, ~\(minutes)min")
        }
        print("")

        let suggestions: [SuggestionResult]
        do {
            suggestions = try await FoundationModelsSuggestionService().generateSuggestions(for: recurring)
            print("Generated suggestions on-device via Apple Foundation Models.\n")
        } catch let error as FoundationModelsSuggestionError {
            print("On-device model unavailable: \(error.description)")
            print("Falling back to cloud provider...\n")
            suggestions = try await CloudSuggestionService().generateSuggestions(for: recurring)
        }

        for suggestion in suggestions {
            print("### \(suggestion.title) [\(suggestion.savings) savings]")
            print(suggestion.rationale)
            print("")
        }

        let writer = try AutomationScriptWriter()
        let paths = try writer.write(suggestions, timestamp: Date())
        print("Wrote \(paths.count) automation script(s):")
        for path in paths {
            print("  \(path.path)")
        }
    } catch {
        FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

await run()
