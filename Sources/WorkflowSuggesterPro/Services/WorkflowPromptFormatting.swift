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
    (time saved vs. effort to build).
    """
}
