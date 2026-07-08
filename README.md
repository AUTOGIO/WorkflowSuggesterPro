# WorkflowSuggesterPro

Reads recent window-activity history from a local [ActivityWatch](https://activitywatch.net) instance, detects recurring app/window patterns, and asks an LLM (on-device Apple Foundation Models, falling back to a cloud provider) to suggest automations worth building. Writes each suggestion out as a commented, reviewable shell script.

## Requirements

- macOS 26+, Apple Silicon
- ActivityWatch running locally with `aw-watcher-window` active (`http://localhost:5600`)
- For the on-device path: Apple Intelligence enabled in System Settings
- For the cloud fallback path (used when Apple Intelligence is unavailable): one of
  - `ANTHROPIC_API_KEY` (optionally `ANTHROPIC_MODEL`, default `claude-sonnet-4-5`)
  - `OPENAI_API_KEY` (optionally `OPENAI_MODEL`, default `gpt-4o-mini`)
  - If both keys are set, Anthropic is used unless `WORKFLOWSUGGESTER_PROVIDER=openai` is set.

Model IDs are env-overridable on purpose — check the current catalog for your provider before relying on the defaults above.

## Run

```sh
swift run WorkflowSuggesterPro
```

Looks back 14 days, requires at least 4 occurrences of the same app/window title to count as "recurring." Generated scripts are written to:

```
~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/
```

Review each script before running it — the LLM's implementation notes are written as comments, not executed automatically.

## Testing the cloud fallback

The cloud path only runs when the on-device model is unavailable, which never happens on a
Mac with Apple Intelligence enabled — so it's otherwise untestable. Force it with:

```sh
WORKFLOWSUGGESTER_FORCE_CLOUD=1 ANTHROPIC_API_KEY=... swift run WorkflowSuggesterPro
```

## Test

```sh
swift test
```
