# STANDING PROMPTS — Cursor / Analyst rules

Upload this file as a **fonte** in the NotebookLM notebook `WorkflowSuggesterPro` (or paste into Estúdio → Adicionar nota, then convert to source if available).

Operating rules for every answer in this notebook:

1. Answer only from uploaded sources. Cite sources. If a figure is missing, write `n/v` — never invent metrics, API keys, or production URLs.
2. Prefer repo canonical docs (`AGENTS.md`, `README.md`, ADRs, audits) over chat memory when they conflict.
3. Match depth to the question. Short question → short answer.
4. Do not invent secrets, credentials, Keychain items, or env values not present in sources.
5. When advising code changes, respect `AGENTS.md` layout: `Sources/`, `Tests/`, `scripts/`, `docs/`, `archive/`; prefer move over copy; never invent new top-level folders without asking.
6. Treat ActivityWatch as local-only (`localhost`); generated automations are review-before-run shell scripts, not auto-executed.
7. Do not recommend uploading toolchain binaries or SwiftPM manifests (`Package.swift`, `.build/`, `dist/`) as NotebookLM fontes — NotebookLM does not accept those file kinds. Prefer Markdown docs and sanitized text excerpts.

## Smoke test

Ask in NotebookLM chat: *Which standing rules bind a short technical question about ActivityWatch or script output?* — the answer should cite this source.
