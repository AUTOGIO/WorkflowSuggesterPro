# WorkflowSuggesterPro

macOS app that reads recent window activity from local [ActivityWatch](https://activitywatch.net), finds recurring app/window patterns, and asks an LLM (on-device Apple Foundation Models, with cloud fallback) to suggest automations. Suggestions are written as commented, reviewable shell scripts.

## Requirements

- macOS 26+, Apple Silicon
- ActivityWatch running locally (`http://localhost:5600`) with `aw-watcher-window`
- Apple Intelligence for on-device suggestions; or `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` for cloud fallback

## Run

```sh
swift run WorkflowSuggesterPro
```

GUI app bundle (optional):

```sh
./scripts/build_and_run.sh
```

Tests:

```sh
swift test
```

If `swift test` fails with "resource fork, Finder information, or similar detritus not allowed", clear extended attributes and retry:

```sh
xattr -cr .build && swift test
```

Generated scripts land in `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/` — review before running.

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | Anthropic API key for cloud fallback | — |
| `OPENAI_API_KEY` | OpenAI API key for cloud fallback | — |
| `WORKFLOWSUGGESTER_FORCE_CLOUD` | Set to any value to skip on-device and use cloud | — |
| `WORKFLOWSUGGESTER_PROVIDER` | Force `anthropic` or `openai` | auto-detect |
| `ANTHROPIC_MODEL` | Override Anthropic model | `claude-sonnet-4-5` |
| `OPENAI_MODEL` | Override OpenAI model | `gpt-4o-mini` |

## Where things live

- `Sources/` — app and core library code
- `Tests/` — unit tests
- `scripts/` — helpers (e.g. build & open the `.app`)
- `docs/` — guides (including NotebookLM wiring)
- `archive/` — obsolete files kept for reference
- `Package.swift` — Swift package definition

## NotebookLM

Dedicated research notebook for this repo: [WorkflowSuggesterPro](https://notebook.google.com/notebook/88b68b2b-6306-438b-a717-c351ff60ccf4).  
Cursor keeps a durable brief in `.cursor/rules/architecture-brief.mdc`. See [`docs/notebooklm.md`](docs/notebooklm.md).
