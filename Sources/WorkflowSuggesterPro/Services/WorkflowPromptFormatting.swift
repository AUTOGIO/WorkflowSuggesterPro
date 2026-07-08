import Foundation

enum WorkflowPromptFormatting {
    static func summary(for workflows: [RecurringWorkflow]) -> String {
        workflows.map { workflow in
            let minutes = Int(workflow.totalDuration / 60)
            return "- \(workflow.app) — \"\(workflow.title)\": \(workflow.occurrences) occurrences, ~\(minutes) min total"
        }.joined(separator: "\n")
    }

    static let instruction = """
    For each workflow that looks automatable, suggest one macOS automation. Rank by ROI \
    (time saved vs. effort to build). Skip workflows that are just routine navigation \
    (e.g. opening a folder) with no real automation opportunity — only suggest something \
    where an automation would meaningfully replace repeated manual steps.

    The "implementation" field must be concrete and runnable: actual shell commands, an \
    `osascript` snippet, a `shortcuts run` invocation, or precise step-by-step instructions \
    naming specific paths, app names, and keyboard shortcuts. Do not write a vague description \
    of what the automation should do — write the automation itself.
    """
}
