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

    The "implementation" field must be concrete and runnable today on macOS using only real \
    shell commands (`open`, `cp`, `rsync`, `mkdir`), `osascript` for basic app activation or \
    Finder operations, or `shortcuts run "<Shortcut Name>"` for an existing Shortcuts automation.

    Rules:
    - Do NOT invent AppleScript commands (e.g. "execute prompt", "activate shortcut") — most apps \
    are not scriptable beyond `activate` and `open`.
    - `shortcuts run` takes a Shortcut name only, never a file path (.scpt, .app).
    - Do NOT invent file paths like ~/Library/Scripts/... unless the workflow data shows that path.
    - Prefer simple, verifiable commands over speculative integrations.
    - For backup workflows, use `rsync` or `cp` with real paths from the workflow title when visible.
    - For app-launch workflows, use `open -a "App Name"` or `osascript -e 'tell application "App Name" to activate'`.
    """

    static let jsonFormatInstruction = """
    Respond with ONLY a JSON array, no markdown code fences, no commentary. Each element must be \
    an object with exactly these string fields: "title", "rationale", "implementation", "savings" \
    (one of "High", "Medium", "Low").

    The "implementation" field must contain one or more runnable shell commands separated by newlines. \
    Wrap the entire osascript script in single quotes; use double quotes only inside the AppleScript \
    (e.g. tell application "Finder"). Do not nest single quotes inside the -e argument.

    Valid examples:
    - "open -a Notes"
    - "osascript -e 'tell application \"Finder\" to open folder \"Documents\" of home'"
    - "rsync -a ~/Documents/ ~/Backups/Documents/"
    - "shortcuts run \"Backup Documents\""

    Invalid examples (do not output these):
    - "osascript -e 'tell application 'ChatGPT' to execute prompt \"...\"'"
    - "shortcuts run \"~/Library/Scripts/foo.scpt\""
    - "osascript -e 'tell application 'Stream Deck' to activate shortcut \"notes\"'"
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
