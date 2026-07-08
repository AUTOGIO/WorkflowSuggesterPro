import Foundation

let lookbackDays = 14
let minOccurrences = 4
// The on-device model's context window is 8192 tokens. Live AW data is a moving target —
// it grows every time this tool (or anything else) is used, so two real runs minutes apart
// hit two different overflow points (8195, then 8193 after other tuning) even with the same
// cap. Keeping real margin here rather than tuning to the exact edge; see also the title
// truncation in WorkflowPromptFormatting, which bounds per-item cost regardless of how long
// file/folder names get.
let maxWorkflowsInPrompt = 5

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

        let promptWorkflows = Array(recurring.prefix(maxWorkflowsInPrompt))
        if promptWorkflows.count < recurring.count {
            print("Sending the top \(promptWorkflows.count) by occurrence to the model (of \(recurring.count) found).\n")
        }

        // WORKFLOWSUGGESTER_FORCE_CLOUD skips the on-device attempt entirely — without it,
        // the cloud path is unreachable on any Mac where Apple Intelligence is enabled and
        // working, which makes it untestable in normal use.
        let forceCloud = ProcessInfo.processInfo.environment["WORKFLOWSUGGESTER_FORCE_CLOUD"] != nil

        let suggestions: [SuggestionResult]
        if forceCloud {
            print("WORKFLOWSUGGESTER_FORCE_CLOUD set — skipping on-device, using cloud provider...\n")
            suggestions = try await CloudSuggestionService().generateSuggestions(for: promptWorkflows)
        } else {
            do {
                suggestions = try await FoundationModelsSuggestionService().generateSuggestions(for: promptWorkflows)
                print("Generated suggestions on-device via Apple Foundation Models.\n")
            } catch let error as FoundationModelsSuggestionError {
                print("On-device model unavailable: \(error.description)")
                print("Falling back to cloud provider...\n")
                suggestions = try await CloudSuggestionService().generateSuggestions(for: promptWorkflows)
            }
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
