# Guide: Wire Cursor ↔ Google NotebookLM (any repo)

Reusable playbook. Copy this file into any project’s `docs/` (or keep a personal copy) and fill the placeholders.

**There is no official NotebookLM public REST API.** Integration uses community MCP / browser automation, or a zero-scraper hand-off of synthesized briefs into Cursor rules. Prefer **Method D** (MCP + durable brief) unless you refuse unofficial tools — then use **Method C** only.

---

## Choose a method

| Method | What it is | Best for | Stability |
|--------|------------|----------|-----------|
| **A — MCP only** | `notebooklm-mcp` in Cursor (`~/.cursor/mcp.json`) | Live Q&A from Chat/Agent | Medium (UI scrapers break) |
| **B — CLI + rules** | `notebooklm-py` / skill adapters + `.cursor/rules` | Repo ↔ notebook sync automation | Medium (heavier) |
| **C — Brief hand-off** | NotebookLM in browser → paste into `.cursor/rules/*.mdc` | Max stability, no scrapers | High |
| **D — A + C (recommended)** | MCP for live queries + brief always in-repo | Daily coding + occasional synthesis | High for rules; MCP optional |

This guide implements **D**. Skip the MCP sections if you want **C** only.

---

## Prerequisites

- Cursor on macOS/Linux/Windows with MCP support
- Node.js 18+ (`node`, `npx`) for Method A/D
- Google account with access to [NotebookLM](https://notebooklm.google.com) / [notebook.google.com](https://notebook.google.com)
- Chrome (MCP drives a real browser session)
- A **dedicated notebook per project** (do not dump unrelated notebooks into one workspace)

---

## Step 0 — Create the notebook

1. Open NotebookLM → **Create new notebook**.
2. Name it after the repo, e.g. `MyProject_Name`.
3. Keep it **private** if sources include PII, secrets, or proprietary docs.
4. Copy the notebook URL. IDs look like:

```text
https://notebook.google.com/notebook/<NOTEBOOK_ID>
https://notebooklm.google.com/notebook/<NOTEBOOK_ID>
```

Both hosts are used by Google; see [Auth gotcha](#auth-gotcha).

5. Upload **Tier-1 sources** only (READMEs, ADRs, skills, architecture docs, current specs). Skip tests, archives, superseded prompts, and anything you would not put in Google’s cloud.

---

## Step 1 — Standing prompts (operating contract)

NotebookLM has no Cursor-style always-on system prompt. Put rules in a **fonte** (preferred) or Studio note.

1. Create `docs/notebooklm-standing-prompts.md` in the repo (template below).
2. In the notebook: **+ Add sources** → upload that file  
   (or Studio → **Add note** → paste → convert to source if the UI offers it).
3. Smoke-test in chat: *Which standing rules bind a short technical question?*

### Template — `docs/notebooklm-standing-prompts.md`

```markdown
# STANDING PROMPTS — Cursor / Analyst rules

Operating rules for every answer in this notebook:

1. Answer only from uploaded sources. Cite sources. If a figure is missing, write `n/v` — never invent metrics.
2. Prefer repo canonical docs (SKILL.md, AGENTS.md, ADRs) over chat memory when they conflict.
3. Match depth to the question. Short question → short answer.
4. Do not invent secrets, credentials, or production URLs not present in sources.
5. When advising code changes, respect the project's layout rules if those files are uploaded.

## Smoke test

Ask: *Which standing rules bind a short question about X?* — the answer should cite this source.
```

Customize bullets 2–5 for the domain (finance, API design, etc.).

---

## Step 2 — Global MCP config (Cursor)

MCP lives in the **user** Cursor config, not in the repo (avoids committing machine paths and keeps auth out of Git).

Edit `~/.cursor/mcp.json` (merge with existing servers; do not wipe other entries):

```json
{
  "mcpServers": {
    "notebooklm": {
      "command": "npx",
      "args": ["-y", "notebooklm-mcp@latest"]
    }
  }
}
```

1. Fully **quit and relaunch** Cursor (MCP loads at startup).
2. Open **Settings → MCP** — `notebooklm` should appear.
3. Trigger auth (first tool call or the server’s login flow) → complete Google login in the Chrome window.
4. Confirm the server shows **green** / connected.

Package reference: [`notebooklm-mcp` on npm](https://www.npmjs.com/package/notebooklm-mcp) (community; MIT; Chrome/Patchright — not an official Google API).

### Auth gotcha

Google may finish login on `notebook.google.com` while stock MCP waiters only watch `notebooklm.google.com`, so auth never “completes” even after a successful Google sign-in.

**Fix:** re-auth with a flow/CLI that accepts **both** hostnames, or complete the session explicitly on `notebooklm.google.com`. Re-check Settings → MCP afterward.

---

## Step 3 — Project pointer rule

In **each** repo that should use a specific notebook:

```bash
mkdir -p .cursor/rules
```

Create `.cursor/rules/notebooklm.mdc`:

```markdown
---
description: NotebookLM integration — which notebook to query and when
alwaysApply: true
---

# NotebookLM ↔ Cursor

## Notebook

- **Name:** `YOUR_NOTEBOOK_NAME`
- **URL:** https://notebook.google.com/notebook/YOUR_NOTEBOOK_ID
- **ID:** `YOUR_NOTEBOOK_ID`

MCP server: `notebooklm` (`npx -y notebooklm-mcp@latest` in `~/.cursor/mcp.json`).
Auth gotcha: login may land on `notebook.google.com` while waiters watch `notebooklm.google.com` — see `docs/cursor-notebooklm-wiring-guide.md`.

## When to call NotebookLM MCP

- Synthesize across many uploaded sources
- Pull citation-backed summaries already refined in the notebook
- Cross-check a proposal against notebook notes before a large change

## When NOT to call NotebookLM

- Live/changing metrics that must be verified from primary sources
- File placement / repo layout (follow AGENTS.md or project rules)
- Day-to-day coding policy already covered by skills or `.cursor/rules`

## Conflict resolution

1. Project skill / AGENTS / ADRs win for policy
2. `.cursor/rules/*-brief.mdc` wins for durable constraints when MCP is offline
3. NotebookLM is a synthesis aid — cite it; do not override canonical docs on conflicts

## Hygiene

- Do not commit Google cookies, MCP auth state, or `.env` secrets
- Keep private notebooks and private repos aligned
- After material source changes, refresh the brief (see project `docs/notebooklm.md`)
```

---

## Step 4 — Engineering brief (offline durability)

Even with MCP green, put a **short durable brief** in-repo so Cursor still has constraints when the scraper is down.

1. In NotebookLM, prompt:

```text
Create a concise Engineering Brief (≤2 pages) with: hard constraints,
current architecture/decisions, conventions, exclusions, open questions,
and citations to uploaded sources. No invented metrics.
```

2. Save as `.cursor/rules/architecture-brief.mdc` (or `project-brief.mdc`):

```markdown
---
description: Durable engineering brief distilled from NotebookLM — constraints when MCP is offline
alwaysApply: true
---

# Project Engineering Brief

<!-- Paste / distill NotebookLM output here. Keep facts tied to sources. -->

## Constraints
## Current decisions
## Conventions
## Exclusions
## Open questions
```

3. Refresh this file whenever the “source of truth” docs or portfolio/architecture memo materially change.

---

## Step 5 — Project instance doc

Add `docs/notebooklm.md` **per repo** (project-specific; not a copy of this guide):

```markdown
# NotebookLM ↔ this repo

Dedicated notebook: [YOUR_NOTEBOOK_NAME](https://notebook.google.com/notebook/YOUR_NOTEBOOK_ID)
ID: `YOUR_NOTEBOOK_ID`

Canonical truth: <!-- e.g. src/.../SKILL.md, docs/adr/ -->
Cursor brief: `.cursor/rules/architecture-brief.mdc`
General wiring guide: `docs/cursor-notebooklm-wiring-guide.md` (or link to your shared copy)

## Sync when these change

| Path | Why |
|------|-----|
| … | … |

**Skip:** tests, archive, superseded prompts, secrets.

## Refresh the Cursor brief

After material changes: regenerate brief in NotebookLM → update `.cursor/rules/*-brief.mdc`.
```

Link the notebook + this habit from the project `README.md` in a short subsection.

---

## Day-to-day workflow

```text
Git repo     = source of truth (edit here)
Cursor       = daily workbench (skills + brief always on)
NotebookLM   = optional synthesizer (MCP or browser)
```

| Task | Where |
|------|--------|
| Short coding / domain questions | Cursor only (skill + brief) |
| Multi-doc synthesis / “what did we decide?” | Cursor → “Query NotebookLM …” or browser |
| Changing policy / architecture | Edit Git → re-upload fontes → refresh brief |
| Live numbers that change often | Primary sources (issuer, API, DB) — not NotebookLM |

**Conflict order:** skill/AGENTS/ADRs → `*-brief.mdc` → NotebookLM.

---

## Verify checklist

- [ ] Dedicated notebook created; URL/ID recorded in `.cursor/rules/notebooklm.mdc` and `docs/notebooklm.md`
- [ ] Standing prompts uploaded as a fonte
- [ ] `~/.cursor/mcp.json` contains `notebooklm`; Cursor relaunched; MCP green
- [ ] Auth completed (both hostnames if needed)
- [ ] Chat smoke test: *From NotebookLM, summarize X with citations*
- [ ] Brief exists in `.cursor/rules/`; agent answers correctly **with MCP disabled**
- [ ] No cookies / auth state committed

---

## Security & hygiene

- Never commit: Google session cookies, Playwright/Patchright profiles, `.env`, MCP auth caches
- Prefer private notebooks for private repos
- Redact secrets before upload; upload a sanitized profile if needed
- Community MCP is unofficial — Google UI changes can break it; the **brief** is your fallback

---

## Optional Method B (CLI sync)

Only if you need scripted upload/sync and accept Python + Playwright:

- [`notebooklm-py`](https://github.com/teng-lin/notebooklm-py)
- Cursor adapters such as [`notebooklm-skill`](https://github.com/ibaifernandez/notebooklm-skill) (`.mdc` under `.cursor/rules/`)

Not required for Method D.

---

## Copy into a new repo (minimal set)

| File | Role |
|------|------|
| `docs/cursor-notebooklm-wiring-guide.md` | This guide (shared) |
| `docs/notebooklm.md` | Per-project notebook URL + sync table |
| `docs/notebooklm-standing-prompts.md` | Upload as NotebookLM fonte |
| `.cursor/rules/notebooklm.mdc` | Pointer + when to call MCP |
| `.cursor/rules/architecture-brief.mdc` | Durable constraints |
| `~/.cursor/mcp.json` | Global MCP (once per machine) |

Placeholders to replace: `YOUR_NOTEBOOK_NAME`, `YOUR_NOTEBOOK_ID`, sync table paths, brief body.

---

## This repo’s instance

For WorkflowSuggesterPro specifics (notebook ID, standing prompts, architecture brief), see [`docs/notebooklm.md`](notebooklm.md).
