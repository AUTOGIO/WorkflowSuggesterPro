import Foundation

enum WorkflowPromptFormatting {
    private static let maxTitleLength = 40

    static func summary(for workflows: [RecurringWorkflow]) -> String {
        workflows.map { workflow in
            let minutes = Int(workflow.totalDuration / 60)
            let title = truncate(workflow.title, to: maxTitleLength)
            return "- \(workflow.app) — \"\(title)\": \(workflow.occurrences) occurrences, ~\(minutes) min total"
        }.joined(separator: "\n")
    }

    /// Real window titles (file paths, long project names) can be arbitrarily long and
    /// inflate the prompt unpredictably as they accumulate — bound each one so total prompt
    /// size stays roughly proportional to workflow count, not to how verbose any single
    /// title happens to be.
    private static func truncate(_ string: String, to maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        return String(string.prefix(maxLength)) + "…"
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

    static let jsonFormatInstruction = """
    Respond with ONLY a JSON array, no markdown code fences, no commentary. Each element must be \
    an object with exactly these string fields: "title", "rationale", "implementation", "savings" \
    (one of "High", "Medium", "Low").
    """

    /// Shared by both the on-device and cloud paths: both parse the model's free-text
    /// response as JSON via `CloudJSONExtraction`, so both need identical formatting
    /// instructions. (The on-device path originally used `@Generable` schema-constrained
    /// generation instead, but real runs showed that consumes most of the model's
    /// 8192-token context as fixed schema/grammar overhead — free-text + manual parsing
    /// sidesteps that entirely and is what's proven reliable for cloud.)
    static func jsonPrompt(for workflows: [RecurringWorkflow]) -> String {
        """
        Recurring workflows detected on this Mac from the last 14 days of window-activity history:

        \(summary(for: workflows))

        \(instruction)

        \(jsonFormatInstruction)
        """
    }

    /// Appended on retry after the on-device model's first response failed to parse as
    /// JSON — smaller on-device models are less reliable than cloud models at strict JSON
    /// formatting, so a stricter, narrower reminder is a reasonable second attempt rather
    /// than repeating the exact same prompt and hoping for a different result.
    static let strictJSONReminder = """
    Your previous response was not valid JSON. Output ONLY a single valid JSON array, nothing \
    else — no markdown code fences, no explanation before or after it. Escape every double-quote \
    character that appears inside a string value with a backslash.
    """
}
