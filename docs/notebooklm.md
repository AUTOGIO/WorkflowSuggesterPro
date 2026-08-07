# NotebookLM ↔ this repo

**Reusable wiring playbook:** [`cursor-notebooklm-wiring-guide.md`](cursor-notebooklm-wiring-guide.md).

Dedicated notebook: [WorkflowSuggesterPro](https://notebook.google.com/notebook/88b68b2b-6306-438b-a717-c351ff60ccf4)  
ID: `88b68b2b-6306-438b-a717-c351ff60ccf4`  
MCP library id: `workflowsuggesterpro`

Canonical truth: `AGENTS.md`, `README.md`, `docs/REPOSITORY_AUDIT.md`, source under `Sources/`.  
Cursor brief: `.cursor/rules/architecture-brief.mdc`  
Standing prompts: [`notebooklm-standing-prompts.md`](notebooklm-standing-prompts.md)

## Sync when these change

| Path | Why |
|------|-----|
| `README.md` | Product purpose, run/env |
| `AGENTS.md` | Layout / hygiene rules |
| `docs/REPOSITORY_AUDIT.md` | Architecture + known risks |
| `docs/notebooklm-standing-prompts.md` | Operating contract |

**Skip:** `Tests/`, `archive/`, `Package.swift`, `.build/`, `dist/`, secrets, Keychain dumps. NotebookLM does not accept SwiftPM manifests / binaries as fontes.

## Refresh the Cursor brief

After material changes to the sync table:

1. In NotebookLM, ask for a ≤2-page engineering brief (constraints, architecture, conventions, exclusions, open questions; no invented metrics).
2. Replace `.cursor/rules/architecture-brief.mdc` (keep YAML frontmatter `alwaysApply: true`).
3. Or edit the brief directly from the updated docs if MCP is unavailable.

## Privacy

Personal productivity context. Prefer a private notebook. Do not commit Google session cookies or MCP auth storage.
