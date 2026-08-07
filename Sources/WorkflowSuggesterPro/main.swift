import Foundation
import WorkflowSuggesterCore

func run() async {
    do {
        let forceCloud = ProcessInfo.processInfo.environment["WORKFLOWSUGGESTER_FORCE_CLOUD"] != nil

        let config = WorkflowPipelineConfig(
            lookbackDays: 14,
            minOccurrences: 4,
            maxWorkflowsInPrompt: 5,
            forceCloud: forceCloud
        )

        let result = try await WorkflowPipeline().run(config: config) { status in
            print(status)
        }

        guard !result.recurringWorkflows.isEmpty else {
            print("No recurring workflows found in the last \(config.lookbackDays) days (threshold: \(config.minOccurrences)+ occurrences).")
            return
        }

        print("Found \(result.recurringWorkflows.count) recurring workflow(s):")
        for workflow in result.recurringWorkflows {
            let minutes = Int(workflow.totalDuration / 60)
            print("  - \(workflow.app) — \"\(workflow.title)\": \(workflow.occurrences)x, ~\(minutes)min")
        }
        print("")

        for suggestion in result.suggestions {
            print("### \(suggestion.title) [\(suggestion.savings) savings]")
            print(suggestion.rationale)
            print("")
        }

        print("Wrote \(result.writtenScriptURLs.count) automation script(s):")
        for path in result.writtenScriptURLs {
            print("  \(path.path)")
        }
    } catch {
        FileHandle.standardError.write("Error: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
}

await run()
