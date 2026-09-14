# WorkflowSuggesterPro — Deep Audit Report

- **Date:** 2026-09-07
- **Repository:** `/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro`
- **Commit audited:** `e0b628b` — *Wire NotebookLM Method D and share a common suggestion pipeline* (branch `master`, working tree clean)
- **Remote:** `https://github.com/AUTOGIO/WorkflowSuggesterPro.git`
- **Machine:** iMac `Mac15,5`, Apple M3, 16 GB, macOS 26.6.2 (25G83), Swift 6.3.3, Xcode 26.6
- **Mode:** Read-only audit. No source file, configuration, permission, service, or ActivityWatch state was modified.

> **Note on scope:** this report supersedes `docs/REPOSITORY_AUDIT.md`, which was written against a different machine and an earlier commit. Section 6 documents that drift. `docs/REPOSITORY_AUDIT.md` was **not** modified or deleted.

---

## 1. Executive Summary

- The app does what the README says at a high level: reads local ActivityWatch window events → filters AFK → detects recurring `app::title` pairs → asks an LLM for automations → writes `.sh` files. **VERIFIED** end to end in source.
- Architecture matches the README's shape, with three targets: `WorkflowSuggesterCore` (library), `WorkflowSuggesterPro` (CLI), `WorkflowSuggesterProApp` (SwiftUI Dock + menu bar). **VERIFIED** in `Package.swift`.
- **Zero third-party dependencies.** `Package.swift` declares no package dependencies; only Apple frameworks are imported (Foundation, FoundationModels, Security, SwiftUI, AppKit, Observation). **VERIFIED**
- **Build readiness: READY.** `swift build` succeeds on this machine (Swift 6.3.3 ≥ tools-version 6.3; macOS 26.6.2 ≥ deployment target 26.0).
- **Test readiness: READY.** `swift test` → **24/24 passed, exit 0**, no warnings, no `xattr` cleanup required.
- **Generated scripts are never executed by the application.** No `Process`, `NSTask`, `posix_spawn`, `system()`, `NSAppleScript`, or `osascript` invocation exists anywhere in `Sources/`. The only filesystem action on a generated script is `NSWorkspace.activateFileViewerSelecting` (reveal in Finder). **VERIFIED — this is the single most important security property and it holds.**
- **Security posture: good, with one design wrinkle.** LLM `implementation` text is written verbatim into a `.sh` file with no sanitization or validation, and the writer actively *strips* a leading `# ` from each line — turning model commentary into live commands.
- Scripts are written `0o644` (**not** executable). **VERIFIED** in code and asserted by test. This blocks `./script.sh` but not `sh script.sh`, so it is a speed bump, not a control.
- **Privacy posture: strong by default on this machine, weak by design on the cloud path.** Window titles are truncated to 40 characters and sent verbatim to Anthropic/OpenAI whenever the cloud path runs. Truncation is not redaction, and there is no consent prompt or warning before the send.
- **Apple Intelligence is available on this Mac** (`SystemLanguageModel.default.availability == .available`, verified with a throwaway probe). The default `.onDeviceFirst` path will therefore stay local — no cloud call, no API key needed.
- **Mandatory blocker: ActivityWatch is not installed and not running.** Nothing listens on `localhost:5600`. The pipeline fails at its first step.
- **Secondary blocker: Rosetta 2 is not installed.** The stable ActivityWatch release (0.13.2, the Homebrew cask) is an x86_64 build and requires Rosetta 2 on this M3.
- API keys are handled correctly: read from env (CLI) or Keychain (GUI), sent only in request headers, **never logged**. `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` are currently **NOT SET** on this machine and no Keychain item exists.
- Documentation has drifted materially: `README.md` references a nonexistent `archive/` directory and an unnecessary `xattr` workaround; `.cursor/rules/architecture-brief.mdc` lists four "known gaps" that the current code has already fixed.
- **Installation readiness: READY after ActivityWatch is installed.** Toolchain, OS, hardware, disk (124 GB free), and on-device model are all in place. No conflicting or duplicate installations exist.

---

## 2. Architecture Map

Actual execution flow, traced from `main.swift` / `AppModel.regenerate()`:

```text
Entry point
  CLI: Sources/WorkflowSuggesterPro/main.swift          (env-based config)
  GUI: WorkflowSuggesterProApp → AppModel.regenerate()  (Keychain-based config)
        ↓                    both construct WorkflowPipelineConfig
WorkflowPipeline.run(config:onStatus:)          [Core/Services/WorkflowPipeline.swift]
        ↓
ActivityWatchService.discoverWindowBucket()     GET /api/0/buckets/  → first key prefixed "aw-watcher-window_"
        ↓
ActivityWatchService.fetchEvents(bucketId:since:)  GET /api/0/buckets/{id}/events?start=<ISO8601>
        ↓
ActivityWatchService.discoverAFKBucket() + fetchEvents   (prefix "aw-watcher-afk_")
        │  └─ on failure: onStatus(...) and continue UNFILTERED (non-fatal)
        ↓
AFKFilter.filterToActive(windowEvents:afkEvents:)   keep window events overlapping any "not-afk" interval
        ↓
RecurrenceDetector.detect(events:minOccurrences:)   group by "app::title", drop empty app/title, sort desc
        │  └─ if empty: return early, NO LLM call, NO files written
        ↓
prefix(maxWorkflowsInPrompt = 5)
        ↓
Provider selection  (see §4)
   ├─ forceCloud             → CloudSuggestionService
   ├─ #available(macOS 26)   → FoundationModelsSuggestionService   ← default path
   │        └─ catch FoundationModelsSuggestionError → CloudSuggestionService
   └─ else                   → CloudSuggestionService
        ↓
WorkflowPromptFormatting.jsonPrompt(for:)   titles truncated to 40 chars; shared by BOTH paths
        ↓
Model invocation
   on-device: LanguageModelSession().respond(to:)          free text, ≤2 attempts
   cloud:     POST api.anthropic.com/v1/messages  (120 s)  or
              POST api.openai.com/v1/chat/completions (120 s), ≤2 attempts
        ↓
CloudJSONExtraction.parseSuggestions(from:)   strip ``` fences → first balanced [...] → decode → normalize savings
        ↓
AutomationScriptWriter.write(_:timestamp:)    ← the only "validation" is JSON shape; content is NOT validated
        ↓
~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/
     <yyyyMMdd-HHmmss>-<index>-<slug>.sh    mode 0644
        ↓
Display only.  CLI prints paths.  GUI lists them and offers "Reveal in Finder".
NOTHING EXECUTES THE SCRIPT.
```

### Boundaries

| # | Layer | Files |
|---|---|---|
| 1 | GUI / app | `Sources/WorkflowSuggesterProApp/` (App, Views, AppModel, stores) |
| 2 | ActivityWatch integration | `Core/Services/ActivityWatchService.swift`, `Core/Models/AWEvent.swift` |
| 3 | Pattern analysis | `Core/Services/AFKFilter.swift`, `RecurrenceDetector.swift` |
| 4 | Provider abstraction | `Core/Services/LLMProvider.swift`, `CloudSuggestionService.swift` |
| 5 | Apple Foundation Models | `Core/Services/FoundationModelsSuggestionService.swift` |
| 6 | Anthropic | `Core/Services/AnthropicProvider.swift` |
| 7 | OpenAI | `Core/Services/OpenAIProvider.swift` |
| 8 | Script generation | `Core/Output/AutomationScriptWriter.swift` |
| 9 | Persistence | `AutomationScriptWriter` (files), `AppPreferencesStore` (UserDefaults), `KeychainStore` (Security.framework) |
| 10 | Logging / errors | Typed enums per layer; CLI → stderr + `exit(1)`; GUI → `lastErrorMessage`. **No log files, no telemetry, no `os_log`.** |

**Orchestration is shared.** Both CLI and GUI call the same `WorkflowPipeline` — the duplicate-orchestration concern in `docs/REPOSITORY_AUDIT.md` no longer applies at this commit.

---

## 3. ActivityWatch Integration — VERIFIED

| Property | Finding | Status |
|---|---|---|
| Endpoint | `http://localhost:5600/api/0` — hardcoded default, injectable via `init(baseURL:)` | VERIFIED |
| HTTP client | `URLSession` with a dedicated `URLSessionConfiguration` | VERIFIED |
| Timeouts | `timeoutIntervalForRequest = 30`, `timeoutIntervalForResource = 60` | VERIFIED (**contradicts the brief's AUDIT-002**) |
| Routes | `GET /buckets/`, `GET /buckets/{id}/events?start=…` | VERIFIED |
| Bucket discovery | Runtime prefix match, `aw-watcher-window_` / `aw-watcher-afk_`. Correctly avoids hardcoding the hostname suffix. | VERIFIED |
| Non-determinism | `buckets.keys.first(where:)` over a `Dictionary` — **key order is not stable**. With more than one matching bucket the chosen one can vary between runs. | VERIFIED (see AUD-06) |
| Event schema | `id: Int?`, `timestamp: Date`, `duration: Double`, `data: [String: AnyCodableValue]`; only `app`, `title`, `status` are ever read | VERIFIED |
| Timestamps | Custom decoder: `.withInternetDateTime + .withFractionalSeconds`, falling back to plain. Handles AW's 6-digit fractional seconds. Covered by a test using a live-captured fixture. | VERIFIED |
| Query range | `start` only, no `end`; `since = now − lookbackDays × 86400` | VERIFIED |
| Polling | **None.** Strictly on-demand, user-initiated. No daemon, no timer, no background scheduler. | VERIFIED |
| Window-bucket failure | Throws `AWError` → CLI exits 1 / GUI shows the error. Fatal, correctly. | VERIFIED |
| AFK-bucket failure | Caught, reported via `onStatus`, pipeline continues on unfiltered events | VERIFIED |
| HTTP error handling | Non-2xx → `AWError.requestFailed("HTTP <code>")`. Response body not included. | VERIFIED |

### Can activity data leave the machine?

**Yes — on the cloud path only.** The exact path:

`AWEvent.data["title"]` → `RecurringWorkflow.title` → `WorkflowPromptFormatting.summary(for:)` (truncated to 40 chars by `truncate(_:to:)`) → `jsonPrompt(for:)` → `AnthropicProvider`/`OpenAIProvider` request body → `api.anthropic.com` / `api.openai.com`.

- **Sanitization / redaction:** none. `truncate` is a length bound to keep prompt size proportional to workflow count — its own doc comment says so. It is not a privacy control, though it does incidentally clip long titles.
- **Consent / warning:** none. No prompt, no dialog, no first-run notice. `PreferencesView` describes provider modes neutrally and never states that window titles are transmitted.
- **Configuration that controls it:** `WORKFLOWSUGGESTER_FORCE_CLOUD` (CLI), `WORKFLOWSUGGESTER_PROVIDER`, and the GUI's provider picker. Default (`.onDeviceFirst`) does **not** transmit — but it silently falls back to cloud if the on-device model errors, and that fallback is not gated on user confirmation.
- **URLs / filenames:** only reach the cloud if they appear inside a window title (browsers commonly put page titles, not URLs, in the title bar; editors commonly put file paths). The code reads only the `aw-watcher-window` bucket — never a browser-URL watcher bucket.

---

## 4. LLM Provider Audit

### Actual precedence (`WorkflowPipeline.run`, lines 69–91)

1. `config.forceCloud == true` → **cloud**, on-device skipped entirely.
2. else `#available(macOS 26.0)` → **on-device**; on `FoundationModelsSuggestionError` → **cloud fallback**.
3. else → **cloud**.

Within the cloud path (`CloudSuggestionService.selectProvider()`):

1. `WORKFLOWSUGGESTER_PROVIDER == "anthropic"` → Anthropic, or throw `missingAPIKey("ANTHROPIC_API_KEY")`.
2. `WORKFLOWSUGGESTER_PROVIDER == "openai"` → OpenAI, or throw `missingAPIKey("OPENAI_API_KEY")`.
3. otherwise auto-detect: **Anthropic wins if its key is present**, else OpenAI, else throw.

**Important nuance (undocumented):** the fallback in step 2 of the outer switch only catches `FoundationModelsSuggestionError`. If `LanguageModelSession.respond` throws a *different* error type twice (e.g. a generation/guardrail error), `FoundationModelsSuggestionService` rethrows it and **no cloud fallback occurs** — the whole run fails. This is arguably the safer, more private behavior, but it is not what "with cloud fallback" implies.

### Environment variables — every documented variable verified against source

| Variable | README says | Code actually does | Required? | Security concern |
|---|---|---|---|---|
| `ANTHROPIC_API_KEY` | Anthropic key for cloud fallback | `AnthropicProvider.init?` returns `nil` without it. Sent as `x-api-key` header. | No (optional; on-device works without) | Correct. Never logged. Read from the process env by the CLI; the **GUI ignores the env and reads Keychain only**. |
| `OPENAI_API_KEY` | OpenAI key for cloud fallback | `OpenAIProvider.init?` returns `nil` without it. Sent as `Authorization: Bearer …`. | No | Same as above. |
| `WORKFLOWSUGGESTER_FORCE_CLOUD` | Any value skips on-device | `main.swift:6` — presence check only (`!= nil`); value ignored, so `=0` and `=false` still force cloud. **CLI only** — the GUI expresses this through its provider picker. | No | Privacy-relevant: setting it exports window titles off-device. An empty-string value still triggers it. |
| `WORKFLOWSUGGESTER_PROVIDER` | Force `anthropic` or `openai` | `CloudSuggestionService:34`, `.lowercased()`. **Only consulted on the cloud path.** An unrecognized value silently falls through to auto-detect rather than erroring. | No | Low. Also used cosmetically for the badge label, which shows `"auto"` when unset even though Anthropic is actually preferred. |
| `ANTHROPIC_MODEL` | Override, default `claude-sonnet-4-5` | `AnthropicProvider:11` — matches exactly. Read once at init. | No | None |
| `OPENAI_MODEL` | Override, default `gpt-4o-mini` | `OpenAIProvider:11` — matches exactly. | No | None |

**No undocumented environment variables exist.** A repo-wide grep for `environment[` and `ProcessInfo` returns only the six above.

### Request / response handling

| Aspect | Anthropic | OpenAI |
|---|---|---|
| Endpoint | `https://api.anthropic.com/v1/messages` | `https://api.openai.com/v1/chat/completions` |
| Auth | `x-api-key` + `anthropic-version: 2023-06-01` | `Authorization: Bearer …` |
| Timeout | 120 s (`URLRequest(timeoutInterval:)`) | 120 s |
| Session | `URLSession.shared` (no custom config) | `URLSession.shared` |
| Params | `max_tokens: 2048`; no temperature/system prompt | no `max_tokens`, no temperature |
| Retry | One retry with `strictJSONReminder`, **only** if the failure is a JSON-parse failure (`CloudJSONExtraction.isJSONParseFailure`). Network/HTTP errors are not retried. Hard cap: 2 attempts. | same |
| Malformed response | `LLMProviderError.invalidResponse` including the first 200 chars of model output | same |
| HTTP error | `requestFailed("… HTTP <code>: <first 300 chars of body>")` | same |
| Prompt/response logging | **None.** No file logging, no `os_log`, no `print` of prompt or completion. | same |
| API-key logging | **None.** Keys exist only in the header value; never interpolated into an error string. **VERIFIED** | same |

**Keychain (GUI):** `kSecClassGenericPassword`, service `WorkflowSuggesterPro`, accounts `anthropic_api_key` / `openai_api_key`. Update-then-add pattern is correct. `kSecAttrAccessible` is not set, so macOS defaults to `kSecAttrAccessibleWhenUnlocked` — an acceptable default for this use.

**Machine state (values never read):** `ANTHROPIC_API_KEY` **NOT SET**, `OPENAI_API_KEY` **NOT SET**, `WORKFLOWSUGGESTER_FORCE_CLOUD` **NOT SET**, `WORKFLOWSUGGESTER_PROVIDER` **NOT SET**, `ANTHROPIC_MODEL` **NOT SET**, `OPENAI_MODEL` **NOT SET**. No Keychain item for service `WorkflowSuggesterPro` exists. No shell rc file references any of them.

---

## 5. Apple Foundation Models Audit

| Aspect | Finding |
|---|---|
| Import | `import FoundationModels` — `FoundationModelsSuggestionService.swift:2` |
| Compile-time gate | `@available(macOS 26.0, iOS 26.0, *)` on both the error enum and the service |
| Package-level gate | `platforms: [.macOS(.v26)]` in `Package.swift` |
| Call-site gate | `if #available(macOS 26.0, iOS 26.0, *)` in `WorkflowPipeline:74` |
| Runtime availability check | `SystemLanguageModel.default.availability` — switch on `.available` / `.unavailable(reason)` before any generation |
| Reasons handled | `.deviceNotEligible`, `.appleIntelligenceNotEnabled`, `.modelNotReady`, plus `@unknown default` |
| Architecture constraint | Not checked in code. Enforced implicitly — Apple Intelligence is Apple-Silicon-only. |
| Generation strategy | Free text + manual JSON parsing, **not** `@Generable` guided generation. The inline comment documents why: fixed schema overhead consumed the model's 8192-token context (7900-token schema overhead; 8193/8192 overflow after shrinking). A well-evidenced decision. |
| Retry | Max 2 attempts, second adds `strictJSONReminder`. Bounded, not a loop. |
| Fallback | Only `FoundationModelsSuggestionError` triggers cloud fallback (see §4 nuance). |
| Session reuse | A fresh `LanguageModelSession()` per attempt — correct, avoids carrying failed context forward. |

**Compile-time vs runtime vs optional:**

1. **Compile-time (mandatory):** macOS 26 SDK, Swift 6.3+ tools. Satisfied — Xcode 26.6 / Swift 6.3.3.
2. **Runtime (for the on-device path):** macOS 26+, Apple Silicon, Apple Intelligence enabled, model downloaded. **VERIFIED available on this machine** — a throwaway `/tmp` probe returned `FM_AVAILABILITY: available` (probe deleted after the run).
3. **Optional:** Anthropic and/or OpenAI keys, needed only if the on-device model is unavailable or cloud is forced.

**README sufficiency:** the README's "Apple Intelligence for on-device suggestions" is adequate but understates the runtime dimension — the framework compiles and the app launches fine with Apple Intelligence off; the failure surfaces only mid-run and silently redirects to cloud (which then fails with `missingAPIKey` if no key is configured). Not a defect, but worth stating explicitly.

---

## 6. Automation Generation & Security Audit

### How a script is produced

1. `SuggestionResult.implementation` — an arbitrary string from the model.
2. `AutomationScriptWriter.scriptContents(for:)` splits it on `\n`, trims whitespace, and **removes a leading `# ` from each line**.
3. Wraps it in a fixed 6-line header (`#!/bin/sh`, title, rationale, savings, and the "Review this script before running" notice).
4. Filename: `<yyyyMMdd-HHmmss>-<index>-<slug>.sh`, slug from `slugify` (non-alphanumerics → `-`, collapsed).
5. Written atomically, then `chmod 0644`.

### Findings

| ID | Severity | Finding | Evidence | Realistic consequence | Mitigation |
|---|---|---|---|---|---|
| SEC-01 | **MEDIUM** | LLM output is written to `.sh` with **no sanitization, validation, allow-listing, or length bound**. Prompt rules (`open`, `cp`, `rsync`, `osascript`, `shortcuts run`) are advisory instructions to the model, never enforced in code. | `AutomationScriptWriter.swift:41–63`; no validation between `parseSuggestions` and `write` | A prompt-injected or simply mistaken model can place `rm -rf ~/…`, `curl … \| sh`, or a credential exfiltration line into a file that looks like a sanctioned product output. Harm requires the user to run it. | Post-generation deny-list or allow-list on the first token of each line; or write the body commented-out by default. |
| SEC-02 | **MEDIUM** | The writer **strips a leading `# `** from every implementation line, converting model commentary into live shell commands — and contradicting the README's "commented … shell scripts". | `AutomationScriptWriter.swift:46–48`; test `scriptContainsExecutableImplementation` asserts `!contents.contains("# echo hello")` | The one safety habit a cautious model has (commenting risky lines, or writing `# explanation` above a command) is actively undone. Explanatory prose becomes an executable line. | Stop stripping `# `. If the goal is tolerating a model that comments everything, detect that case explicitly instead of unconditionally uncommenting. |
| SEC-03 | **LOW** | `0o644` is described as making scripts non-executable, but `sh file.sh` / `zsh file.sh` runs regardless of the exec bit. | `AutomationScriptWriter.swift:35` | The permission is a speed bump against `./file.sh`, not a control. It correctly prevents accidental double-click / `open` execution. | Keep 0644 (it is the right default), but do not treat it as the primary control — SEC-01/SEC-02 are. |
| SEC-04 | **INFORMATIONAL** | **No execution path exists.** Repo-wide grep for `Process(`, `NSTask`, `posix_spawn`, `system(`, `/bin/sh`, `/bin/bash`, `/bin/zsh`, `osascript`, `NSAppleScript`, `NSUserUnixTask` finds **zero** invocations in `Sources/`. `/bin/sh` appears only as the shebang string; `osascript` only inside prompt text. The only script-file action is `NSWorkspace.activateFileViewerSelecting`. | `Sources/` grep; `AppModel.swift:143–150` | "Review before running" is **structurally enforced**, not merely documented. The app cannot run a generated script even if the model asks it to. | None needed. Preserve this property — it is the project's strongest security guarantee. |
| SEC-05 | **LOW** | Filename collision: same second + same index overwrites silently. No `.sh` extension check on write, no collision suffix. | `AutomationScriptWriter.swift:32–34` | Only reachable by two runs finishing in the same second — practically negligible for a manual tool. Path traversal is **not** possible: `slugify` keeps only alphanumerics, so `../` and `/` cannot survive. | Optional: append a short random suffix. |
| SEC-06 | **LOW** | Up to 300 characters of an API error body and 200 characters of raw model output are surfaced in `lastErrorMessage` / stderr. | `AnthropicProvider.swift:27–28`, `OpenAIProvider.swift:26–27`, `CloudJSONExtraction.swift:9` | Provider error bodies can echo request metadata. **API keys are not included** — keys live only in headers. Low risk on a personal machine. | Acceptable as-is. |
| SEC-07 | **MEDIUM (privacy)** | Window titles reach a third-party API on the cloud path with no redaction and no consent step; the on-device→cloud fallback is automatic. | §3 data path; `WorkflowPipeline.swift:80–85` | A title such as `Contract – AcmeCo – R$ 1.2M.docx – Pages` is transmitted (truncated at 40 chars). The user is never told this is about to happen. | Add a one-time confirmation before the first cloud send, and state the behavior in `PreferencesView` and the README. |
| SEC-08 | **LOW** | `swift test` writes into the **real** `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/` — `AutomationScriptWriter` has no injectable output directory. | `AutomationScriptWriter.init()`; `AutomationScriptWriterTests.swift` | Tests create the production directory and write/delete real files there. Verified clean-up: the directory was empty after the run. A failed test would leave stray `.sh` files behind. | Add an `init(outputDirectory:)` overload and point tests at a temp directory. |
| SEC-09 | **LOW** | `scripts/build_and_run.sh` produces an **unsigned, ad-hoc, unsandboxed** `.app` — no entitlements, no `codesign`, no hardened runtime. | `scripts/build_and_run.sh:23–53` (no `codesign` call, no entitlements file) | Normal for a personal tool, but the app runs with full user-level file access and will need manual Gatekeeper approval on first launch. `open -n` also permits multiple concurrent instances. | Fine for personal use. Ad-hoc sign (`codesign -s -`) if Gatekeeper friction appears. |
| AUD-06 | **LOW** | Bucket discovery uses `Dictionary.keys.first(where:)` — unordered. With two `aw-watcher-window_*` buckets (e.g. after a hostname change) the selection is non-deterministic between runs. | `ActivityWatchService.swift:44` | Silently analyses the wrong machine's history. | Sort matching keys before choosing, or prefer the bucket whose suffix equals the local hostname. |

**Does any path bypass human review?** **No.** Verified by exhaustive grep of every process-spawning and AppleScript API. The pipeline's terminal operation is a file write; the GUI's terminal operation is a Finder reveal.

---

## 7. Privacy Audit

| Data | Source | Processed locally? | Sent externally? | Stored? | Destination |
|---|---|---|---|---|---|
| Window titles | AW `aw-watcher-window` bucket | Yes | **Only on cloud path** (truncated to 40 chars, unredacted) | Yes — inside generated `.sh` headers | Anthropic / OpenAI |
| Application names | same | Yes | **Only on cloud path** (full) | Yes — in `.sh` headers | Anthropic / OpenAI |
| Browser page titles | same (they are window titles) | Yes | Only on cloud path | Yes | Anthropic / OpenAI |
| URLs | Not read — no browser-URL watcher bucket is queried | n/a | Only if embedded in a window title | Only if in a title | — |
| Filenames / paths | Only via window titles (editors put paths in title bars) | Yes | Only on cloud path | Yes | Anthropic / OpenAI |
| Event timestamps / durations | AW | Yes | **No** — only aggregate occurrence counts and total minutes are in the prompt | No | — |
| AFK status | AW `aw-watcher-afk` bucket | Yes | **No** — used only to filter | No | — |
| Prompt text | Built locally | Yes | Yes, on cloud path | **No** — never written to disk | Anthropic / OpenAI |
| Model responses | LLM | Yes | n/a | Yes — as `.sh` files | Local disk |
| API keys | User | Yes | Only as auth headers to their own provider | Keychain (GUI) or env (CLI) | Anthropic / OpenAI |
| Generated suggestions | LLM | Yes | No | `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/`, mode 0644 | Local disk |

### ON-DEVICE PATH (default; available on this machine)
AW (localhost) → local filtering → local Apple Foundation Models → local `.sh` files. **Nothing leaves the machine.** No telemetry, no analytics, no crash reporting, no network calls other than `localhost:5600`.

### CLOUD PATH (forced, or automatic fallback)
Identical up to prompt construction, then an HTTPS POST carrying app names and 40-char-truncated window titles to Anthropic or OpenAI.

### Privacy gaps vs. reasonable expectation

1. **Silent fallback.** A user selecting "Automatic (on-device first)" reasonably expects local processing. If Apple Intelligence becomes unavailable (model updating, feature toggled off), the app transmits window titles to a cloud provider with a status-line message and no confirmation.
2. **No disclosure of what is transmitted.** Neither README nor `PreferencesView` states that window titles are sent. `PreferencesView` discusses key storage but not data egress.
3. **Truncation reads as protection but is not.** 40 characters is enough for `Contract – AcmeCo – Q3 renewal – 2026`. The code comment is honest that this is a size bound; the user-facing docs never mention it at all.
4. **Generated scripts inherit sensitive context.** Rationale text quoting a window title is written to disk in a directory not covered by any special protection. Mode 0644 means group/other-readable.

---

## 8. Build System Audit

### `Package.swift` — VERIFIED

| Property | Value |
|---|---|
| Swift tools version | `6.3` |
| Language mode | `swiftLanguageModes: [.v6]` (full strict concurrency) |
| Platforms | `.macOS(.v26)` — no iOS/other |
| Package dependencies | **None** |
| Products | 2 executables: `WorkflowSuggesterPro`, `WorkflowSuggesterProApp` |
| Targets | `WorkflowSuggesterCore` (library), 2 executable targets, 1 test target |
| Resources | None declared, none present |
| Conditional compilation | No `#if` blocks; gating is via `@available` / `#available` only |
| System frameworks | Foundation, FoundationModels, Security, SwiftUI, AppKit, Observation — all Apple, linked implicitly |
| Entry points | `main.swift` (top-level code) for CLI; `@main struct WorkflowSuggesterProApp: App` for GUI |
| Network deps at build time | None (no remote packages to resolve) |

The GUI is declared as an `executableTarget`, not a bundled app — hence `scripts/build_and_run.sh`.

### `scripts/build_and_run.sh` — inspected line by line before any execution decision

What it does, in order:

1. `set -euo pipefail`; `MODE="${1:-run}"`.
2. Derives `ROOT_DIR` from `BASH_SOURCE` — no hardcoded user paths. **Good.**
3. `pkill -x "WorkflowSuggesterProApp"` — exact-name match, `|| true`. Kills only this app.
4. `swift build --product WorkflowSuggesterProApp`.
5. **`rm -rf "$DIST_DIR/WorkflowSuggester Pro.app"`** — the only destructive command. Bounded to a fully-derived path under the repo, and correctly quoted. Not reachable outside the repo.
6. `mkdir -p`, `cp` the binary, `chmod +x` **the app binary** (not a generated script).
7. Generates `Info.plist` via heredoc: bundle id `local.workflowsuggesterpro.app`, `LSMinimumSystemVersion 26.0`, version 0.1.0, deliberately no `LSUIElement`.
8. Mode dispatch: `run` → `open -n` the bundle; `debug` → `lldb`; `logs` → open + `log stream`; `verify` → open + `sleep 2` + `pgrep`.

**No** `codesign`, **no** entitlements, **no** `sudo`, **no** writes outside `$ROOT_DIR/dist`, **no** network access, **no** LaunchAgent creation.

**Assessment: SAFE, but with side effects** — it kills a running instance, deletes and rebuilds `dist/`, and **launches a GUI app**. Launching an app is a state change, so per the audit's non-destructive rule this script was **not executed**. It is safe to run at Stage 7 of the install plan.

---

## 9. Test Audit & Results

### Coverage

| Area | File | Tests | Covered |
|---|---|---|---|
| AFK filtering | `AFKFilterTests.swift` | 5 | Overlap, exclusion, partial overlap, empty AFK data, afk-only data |
| AW decoding | `AWEventDecodingTests.swift` | 2 | Live-captured fixture; proves plain ISO8601 rejects AW timestamps |
| Script writing | `AutomationScriptWriterTests.swift` | 3 | File creation, shebang, **0644 permissions**, uncommenting behavior, review notice, slugification |
| JSON extraction | `CloudJSONExtractionTests.swift` | 9 | Bare array, preamble, trailing text, markdown fences, escaped quotes, multiple items, savings normalization, 2 failure cases |
| Recurrence | `RecurrenceDetectorTests.swift` | 5 | Grouping, threshold, missing/empty fields, sort order |
| **Total** | | **24** | |

**Not covered:** `ActivityWatchService` (no URLProtocol stub — bucket discovery, HTTP status handling, and the query-item construction are all untested); `AnthropicProvider` / `OpenAIProvider` (request construction, header handling, error paths); `CloudSuggestionService.selectProvider` **precedence logic** — the most behaviour-defining untested function in the codebase; `FoundationModelsSuggestionService`; `WorkflowPipeline` orchestration and fallback branches; `KeychainStore`; `AppPreferencesStore`; all SwiftUI views. No integration tests, no security/fuzz tests on `implementation` content.

### Results

```console
$ cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro
$ swift build
Build complete! (0.16s)                       # exit 0

$ swift test
✔ Test run with 24 tests in 0 suites passed after 0.004 seconds.
                                              # exit 0
```

- **24/24 passed. 0 failures. 0 warnings.**
- **The documented extended-attribute failure did NOT occur.** Before running anything, `.build` was inspected: it carries **3533 `com.apple.provenance` xattrs and zero `com.apple.FinderInfo` / `com.apple.ResourceFork`** attributes. `com.apple.provenance` does not trigger the codesign "resource fork, Finder information, or similar detritus" error. **`xattr -cr .build` was therefore neither safe-but-needed nor run — it was simply unnecessary.**
- For the record, had it been needed: `.build` **is** the correct scope (it is gitignored, fully regenerable by `swift build`, and contains no user data). Running `xattr -cr` on the repository root or `$HOME` would not be.
- **Side effect disclosed:** `AutomationScriptWriterTests` writes real files into `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/` and deletes them. Verified empty after the run (see SEC-08).

---

## 10. Documentation Drift

### `README.md`

| Claim | Reality | Status |
|---|---|---|
| "Suggestions are written as **commented**, reviewable shell scripts" | Only the 6-line header is commented. The body is live shell code, and the writer actively **strips** `# ` prefixes. | **CONTRADICTED** (see SEC-02) |
| `archive/` — "obsolete files kept for reference" | **No `archive/` directory exists.** | **CONTRADICTED** |
| "If `swift test` fails … `xattr -cr .build && swift test`" | Not needed on this machine; only `com.apple.provenance` xattrs present, tests pass clean. | **NOT APPLICABLE** here |
| macOS 26+, Apple Silicon | Matches `Package.swift` and `@available` gates | VERIFIED |
| `http://localhost:5600` + `aw-watcher-window` | Matches `ActivityWatchService` | VERIFIED |
| All 6 env vars and their defaults | Match source exactly | VERIFIED |
| Output path | Matches `AutomationScriptWriter` | VERIFIED |
| — | **Undocumented:** the GUI reads API keys from **Keychain only** and ignores the process environment; the CLI reads the **environment only** and never consults the Keychain. Anyone who exports `ANTHROPIC_API_KEY` and then launches the GUI will hit `missingAPIKey`. | **MISSING** |
| — | **Undocumented:** window titles are transmitted to the cloud provider on the cloud path. | **MISSING** (see SEC-07) |
| — | **Undocumented:** `WORKFLOWSUGGESTER_FORCE_CLOUD` is a presence check — `=0` and `=false` still force cloud. | **MISSING** |
| — | **Undocumented:** cloud fallback triggers only on `FoundationModelsSuggestionError`; other on-device errors abort the run. | **MISSING** |

### `.cursor/rules/architecture-brief.mdc`

Constraints, pipeline description, target list, and output path all match the code. **The "Known gaps" section is stale and should not be trusted:**

| Brief claims | Reality at `e0b628b` | Status |
|---|---|---|
| AUDIT-001: tracked `dist/` binary | No `dist/` in the tree; working tree clean | **CONTRADICTED** |
| AUDIT-002: no timeouts on AW / LLM `URLSession` | AW 30 s/60 s; both providers 120 s | **CONTRADICTED** |
| AUDIT-003: generated scripts default `chmod 755` | `0o644`, asserted by test | **CONTRADICTED** |
| "Limited tests for LLM/JSON/script-writer paths" | JSON extraction (9 tests) and script writer (3 tests) are now covered; **provider selection and network layers remain untested** | **PARTIALLY VERIFIED** |
| Conventions reference `archive/` | Does not exist | **CONTRADICTED** |
| Open question: "purpose of empty `reports/`" | No `reports/` in the repo | Resolved / stale |

### `docs/REPOSITORY_AUDIT.md`

Written against a **different machine and an earlier commit**, and should be treated as historical:

- Records repo root `/Users/eduardofgiovannini/Documents/GitHub/WorkflowSuggesterPro` — actual root is `/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro`.
- Records "Swift 6.4, Xcode 27.0, macOS 27.0" — this machine is **Swift 6.3.3, Xcode 26.6, macOS 26.6.2**.
- Records "12 tests" — there are now **24**.
- Describes uncommitted changes and an `archive/` directory that no longer exist; the working tree is clean.
- AUDIT-001/002/003/005/007/009/010 are all fixed or non-existent at this commit (see table above).
- **Still valid:** AUDIT-004 (AFKFilter is O(n×m) — confirmed, `filter` over `contains`; acceptable at personal-history scale), AUDIT-011 (macOS 26 floor), AUDIT-012 (no persistent state beyond Keychain/UserDefaults/scripts).

### `AGENTS.md`

Layout rules are consistent with the tree, except that `archive/`, `config/`, `data/`, and `assets/` are described but do not exist — `AGENTS.md` presents these as "create when needed", so this is a convention document, not drift.

**`archive/` was treated as historical per instruction — and there was nothing to exclude, because it does not exist. No obsolete code influenced this assessment.**

---

## 11. Repository Findings Summary

| Severity | Finding | Evidence | Impact | Recommendation |
|---|---|---|---|---|
| MEDIUM | Unsanitized LLM output written to `.sh` (SEC-01) | `AutomationScriptWriter.swift:41–63` | Arbitrary shell content in a trusted-looking file | Add a deny-list check post-generation |
| MEDIUM | Writer uncomments `# `-prefixed lines (SEC-02) | `AutomationScriptWriter.swift:46–48` | Model commentary becomes executable; contradicts README | Stop stripping `# ` |
| MEDIUM | Window titles sent to cloud without redaction or consent (SEC-07) | §3 data path | Sensitive project/client names leave the machine | One-time consent + document the behavior |
| LOW | `0o644` overstated as a control (SEC-03) | `AutomationScriptWriter.swift:35` | `sh file.sh` bypasses it | Keep, but do not rely on it |
| LOW | Tests write to the real Application Support directory (SEC-08) | `AutomationScriptWriter.init()` | Test failure leaves stray files in production path | Inject the output directory |
| LOW | Non-deterministic bucket selection (AUD-06) | `ActivityWatchService.swift:44` | Wrong bucket after hostname change | Sort keys / prefer hostname match |
| LOW | Unsigned, unsandboxed app bundle (SEC-09) | `scripts/build_and_run.sh` | Gatekeeper friction; full user file access | Acceptable personally; ad-hoc sign if needed |
| LOW | Error bodies surfaced to UI/stderr (SEC-06) | Provider files | Metadata echo; **no key leakage** | Acceptable |
| LOW | Filename collision within one second (SEC-05) | `AutomationScriptWriter.swift:32` | Silent overwrite | Optional random suffix |
| LOW | Provider-selection precedence untested | `Tests/` | The most behavior-defining function has no test | Add a table-driven test |
| LOW | `WORKFLOWSUGGESTER_FORCE_CLOUD` presence-only semantics | `main.swift:6` | `=0` still forces cloud | Document, or parse the value |
| LOW | Cloud fallback only on `FoundationModelsSuggestionError` | `WorkflowPipeline.swift:80` | Other on-device errors abort the run | Document the intended behavior |
| INFO | **No execution path for generated scripts** (SEC-04) | Repo-wide grep | Review-before-run is structurally enforced | **Preserve this property** |
| INFO | Zero third-party dependencies | `Package.swift` | Minimal supply-chain surface | Preserve |
| INFO | AFKFilter O(n×m) | `AFKFilter.swift:25–30` | Fine at personal scale; degrades on very long lookbacks | Revisit only if lookback grows large |
| INFO | macOS 26 floor | `Package.swift` | Narrow compatibility by design | Intentional |

**Totals: 0 Critical, 0 High, 3 Medium, 9 Low, 4 Informational.**

---

## 12. Open Questions

Only items that cannot be resolved from the repository or the machine:

1. **Cloud path at all?** Apple Intelligence is available here, so the on-device path will serve every run. Do you want Anthropic/OpenAI keys configured as a fallback, or should the cloud path stay unconfigured so that an on-device failure fails loudly rather than transmitting window titles? *(Leaving it unconfigured is the stronger privacy posture and requires no work.)*
2. **ActivityWatch build choice.** Stable 0.13.2 via Homebrew (x86_64, requires installing Rosetta 2), or the native arm64 `v0.14.0bX` prerelease? Both are covered in `INSTALL_PLAN.md`.
3. **`docs/REPOSITORY_AUDIT.md`** is stale in the ways listed in §10. Correct it in place, move it to an `archive/` directory (which `AGENTS.md` anticipates but does not yet exist), or leave it? *No action was taken on it.*
4. **`.cursor/rules/architecture-brief.mdc` "Known gaps"** actively misdescribes the current code (timeouts, 755, `dist/`). Since it is `alwaysApply: true`, it is steering every Cursor session with false constraints. Should it be corrected?
5. Is the un-commenting behavior in `AutomationScriptWriter` (SEC-02) intentional product behavior, or an artifact of working around a model that over-commented? The test asserting it suggests intent, but it conflicts with the README's stated design.
