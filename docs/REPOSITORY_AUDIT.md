# Repository Audit Report

## 1. Executive Summary

WorkflowSuggesterPro is a well-structured, early-stage macOS personal-productivity tool (6 commits, ~13 MB including a pre-built app binary). It reads ActivityWatch window-activity data, detects recurring patterns, uses LLMs (on-device Apple Foundation Models or cloud Anthropic/OpenAI) to generate automation suggestions, and writes them as commented shell scripts for the user to review.

The codebase is clean, idiomatic Swift 6, with no critical security vulnerabilities. The main risks are: a committed binary in `dist/`, lack of timeout/cancellation on network calls, generated scripts being marked executable (755) by default, and limited test coverage of the LLM/network layer.

**Findings by severity:** 0 Critical, 2 High, 4 Medium, 5 Low, 2 Informational.

## 2. Audit Scope and Limitations

- Full read-only source inspection of all application code, tests, scripts, and configuration.
- Build validation: `swift build` succeeded (Swift 6.4, Xcode 27.0, macOS 27.0, Apple Silicon).
- Test validation: all 12 tests passed (after clearing extended attributes on `.build/`).
- No credentials were available to test cloud LLM paths.
- ActivityWatch was not running, so runtime behavior was not observed.

## 3. Initial Repository State

| Property | Value |
|----------|-------|
| Root | `/Users/eduardofgiovannini/Documents/GitHub/WorkflowSuggesterPro` |
| Branch | `master` |
| Remote | `origin` (GitHub, presumably) |
| Commits | 6 total |
| Size | 13 MB |
| Uncommitted changes | Modified `.gitignore`, `README.md`; renamed `script/` → `scripts/`; new `AGENTS.md`, `WorkflowSuggesterPro.code-workspace`, `archive/` |
| Submodules | None |
| Worktrees | None |

## 4. Repository Purpose

**Intended purpose:** Personal macOS automation assistant that monitors window-usage patterns via ActivityWatch, identifies recurring workflows, and generates shell-script automations using LLMs.

**Likely user:** The repository owner (single-developer personal tool).

**Primary workflow:**
1. User runs the CLI (`swift run WorkflowSuggesterPro`) or GUI app.
2. App queries local ActivityWatch API for 14 days of window events.
3. AFK periods are filtered out.
4. Recurring app+title pairs (≥4 occurrences) are detected.
5. Top 5 workflows are sent to an LLM for automation suggestions.
6. Suggestions are written as commented `.sh` scripts to `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/`.

**External dependencies:** ActivityWatch (localhost:5600), optionally Anthropic/OpenAI APIs.

## 5. Repository Map

| Path | Purpose |
|------|---------|
| `Package.swift` | SwiftPM manifest (swift-tools-version 6.3, macOS 26+) |
| `Sources/WorkflowSuggesterCore/` | Shared library: models, AW service, LLM providers, recurrence detection, script writing |
| `Sources/WorkflowSuggesterPro/` | CLI executable (single `main.swift`) |
| `Sources/WorkflowSuggesterProApp/` | SwiftUI GUI app (Dock + menu bar) |
| `Tests/WorkflowSuggesterProTests/` | Unit tests (3 files) |
| `scripts/build_and_run.sh` | Builds GUI app bundle into `dist/` |
| `dist/` | Pre-built `.app` bundle (committed binary) |
| `archive/` | Obsolete files |
| `reports/` | Empty directory with `.DS_Store` files |

## 6. Technology Stack

| Technology | Evidence |
|------------|----------|
| Swift 6 (language mode v6) | `Package.swift` line 40 |
| SwiftPM (swift-tools-version 6.3) | `Package.swift` line 1 |
| macOS 26+ | `Package.swift` line 7 |
| Apple FoundationModels framework | `FoundationModelsSuggestionService.swift` |
| SwiftUI + AppKit | `WorkflowSuggesterProApp.swift` |
| macOS Keychain (Security framework) | `KeychainStore.swift` |
| Anthropic Messages API | `AnthropicProvider.swift` |
| OpenAI Chat Completions API | `OpenAIProvider.swift` |
| ActivityWatch REST API | `ActivityWatchService.swift` |
| Swift Testing framework | Test files use `@Test` macro |

## 7. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│  CLI (main.swift)  │  GUI App (SwiftUI/AppKit)  │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────▼───────────┐
         │  WorkflowSuggesterCore │
         │  ├─ ActivityWatchService (actor)
         │  ├─ AFKFilter
         │  ├─ RecurrenceDetector
         │  ├─ FoundationModelsSuggestionService
         │  ├─ CloudSuggestionService
         │  │    ├─ AnthropicProvider
         │  │    └─ OpenAIProvider
         │  └─ AutomationScriptWriter
         └───────────────────────┘
```

The architecture is simple, appropriate for a single-developer tool, and well-layered. The core library is cleanly separated from both UI targets.

## 8. Build, Test, and Run Procedure

| Step | Command | Notes |
|------|---------|-------|
| Build CLI | `swift build --product WorkflowSuggesterPro` | Requires macOS 26 SDK |
| Build GUI | `swift build --product WorkflowSuggesterProApp` | Same |
| Run CLI | `swift run WorkflowSuggesterPro` | Needs ActivityWatch running |
| Run GUI | `./scripts/build_and_run.sh` | Builds + opens `.app` |
| Test | `swift test` | No external deps needed |

**Required environment variables (optional):**
- `ANTHROPIC_API_KEY` — for cloud fallback (Anthropic)
- `OPENAI_API_KEY` — for cloud fallback (OpenAI)
- `WORKFLOWSUGGESTER_FORCE_CLOUD` — skip on-device, use cloud
- `WORKFLOWSUGGESTER_PROVIDER` — force `anthropic` or `openai`
- `ANTHROPIC_MODEL` — override model (default: `claude-sonnet-4-5`)
- `OPENAI_MODEL` — override model (default: `gpt-4o-mini`)

## 9. Commands Executed

| Command | Exit Code | Result |
|---------|-----------|--------|
| `git status --short` | 0 | Uncommitted changes listed |
| `git log -10 --oneline` | 0 | 6 commits |
| `swift --version` | 0 | Swift 6.4 (swiftlang-6.4.0.25.4, arm64-apple-macosx27.0.0) |
| `xcodebuild -version` | 0 | Xcode 27.0 (27A5218g) |
| `du -sh .` | 0 | 13 MB |
| `find` (file/dir listing) | 0 | Complete map obtained |
| `swift build` | 0 | Build complete (2.14 sec) |
| `swift test` (first attempt) | 1 | CodeSign failed: "resource fork, Finder information, or similar detritus not allowed" — caused by macOS extended attributes on `.build/` |
| `xattr -cr .build && swift test` | 0 | All 12 tests passed (0.003 sec) |

## 10. Findings Summary

| ID | Severity | Priority | Category | Finding | Confidence |
|---|---|---|---|---|---|
| AUDIT-001 | High | P1 | Repository hygiene | Committed binary in dist/ | Confirmed |
| AUDIT-002 | High | P1 | Reliability | No timeouts on network requests | Confirmed |
| AUDIT-003 | Medium | P2 | Security | Generated scripts chmod 755 by default | Confirmed |
| AUDIT-004 | Medium | P2 | Correctness | AFKFilter O(n×m) complexity | Confirmed |
| AUDIT-005 | Medium | P2 | Testing | No tests for LLM providers or script writer | Confirmed |
| AUDIT-006 | Medium | P2 | Repository hygiene | .DS_Store files committed | Confirmed |
| AUDIT-007 | Low | P3 | Reliability | No cancellation support in GUI generation | Confirmed |
| AUDIT-008 | Low | P3 | Documentation | Undocumented environment variables | Confirmed |
| AUDIT-009 | Low | P3 | Architecture | Duplicate orchestration logic in CLI and AppModel | Confirmed |
| AUDIT-010 | Low | P3 | Repository hygiene | Empty reports/ directory committed | Confirmed |
| AUDIT-011 | Informational | — | macOS | Requires macOS 26 (Tahoe) — extremely narrow compatibility | Confirmed |
| AUDIT-012 | Informational | — | Architecture | No persistent state beyond Keychain and generated scripts | Confirmed |
| AUDIT-013 | Low | P3 | Reliability | `swift test` fails without `xattr -cr .build` due to resource fork detritus | Confirmed |

## 11. Critical Findings

None.

## 12. High Findings

### [AUDIT-001] Committed binary in dist/

- Severity: High
- Priority: P1
- Confidence: Confirmed
- Category: Repository hygiene
- File: `dist/WorkflowSuggester Pro.app/Contents/MacOS/WorkflowSuggesterProApp`
- Location: 1.3 MB Mach-O binary
- Evidence:
  - `ls -la dist/WorkflowSuggester\ Pro.app/Contents/MacOS/` shows a 1.3 MB executable.
  - `.gitignore` includes `dist/` but the file is already tracked.
- Impact:
  - Bloats repository history permanently. Binary diffs are meaningless. Every clone downloads stale build artifacts.
- Recommendation:
  - `git rm -r --cached dist/` and commit. The `.gitignore` already covers `dist/`.
- Validation:
  - After removal, `git status` shows `dist/` as untracked and ignored.

### [AUDIT-002] No timeouts on network requests

- Severity: High
- Priority: P1
- Confidence: Confirmed
- Category: Reliability
- File: `Sources/WorkflowSuggesterCore/Services/ActivityWatchService.swift`, `AnthropicProvider.swift`, `OpenAIProvider.swift`
- Location: All `URLSession.shared.data(from:)` / `data(for:)` calls
- Evidence:
  - No `timeoutInterval` set on any `URLRequest`.
  - `URLSession.shared` uses the system default (60s for request, 7 days for resource).
  - LLM generation can be slow; no user-facing timeout or cancellation.
- Impact:
  - CLI or GUI can hang indefinitely if ActivityWatch or a cloud API becomes unresponsive.
- Recommendation:
  - Set `timeoutIntervalForRequest` (e.g. 30s for AW, 120s for LLM) on each request or use a custom `URLSession` configuration.
- Validation:
  - Verify timeout behavior by pointing at a non-responding port.

## 13. Medium Findings

### [AUDIT-003] Generated scripts are chmod 755

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Security
- File: `Sources/WorkflowSuggesterCore/Output/AutomationScriptWriter.swift`
- Location: Line 35 — `.posixPermissions: 0o755`
- Evidence:
  - Every generated script is immediately made executable.
  - Scripts contain LLM-generated content that the user is told to "review before running."
- Impact:
  - Accidental double-click or spotlight execution could run unreviewed LLM-generated code.
- Recommendation:
  - Write scripts as 644 (non-executable). Let the user `chmod +x` after review.
- Validation:
  - Generate a script and verify `ls -l` shows `-rw-r--r--`.

### [AUDIT-004] AFKFilter O(n×m) complexity

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Correctness
- File: `Sources/WorkflowSuggesterCore/Services/AFKFilter.swift`
- Location: `filterToActive` method — nested iteration over all AFK intervals for every window event
- Evidence:
  - For 14 days of data, window events can be 10,000+ and AFK intervals hundreds. Current implementation is O(window × afk).
- Impact:
  - Noticeable latency with large datasets; unlikely to be a blocker for typical personal use.
- Recommendation:
  - Sort AFK intervals by start time and use binary search for overlap detection.
- Validation:
  - Benchmark with synthetic 20,000-event dataset.

### [AUDIT-005] No tests for LLM providers or script writer

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Testing
- File: `Tests/WorkflowSuggesterProTests/`
- Location: Only `RecurrenceDetectorTests`, `AWEventDecodingTests`, `AFKFilterTests` exist
- Evidence:
  - No test coverage for `CloudJSONExtraction`, `AutomationScriptWriter`, `AnthropicProvider`, `OpenAIProvider`.
- Impact:
  - JSON parsing regressions or script-writing bugs would go undetected.
- Recommendation:
  - Add unit tests for `CloudJSONExtraction.parseSuggestions` (valid JSON, malformed input, edge cases) and `AutomationScriptWriter` (file creation, slugification).
- Validation:
  - `swift test` passes with new tests covering these paths.

### [AUDIT-006] .DS_Store files committed

- Severity: Medium
- Priority: P2
- Confidence: Confirmed
- Category: Repository hygiene
- File: `.DS_Store`, `Sources/.DS_Store`, `Sources/WorkflowSuggesterPro/.DS_Store`, `dist/.DS_Store`, `reports/.DS_Store`, `reports/session/.DS_Store`
- Location: Multiple directories
- Evidence:
  - `find` output shows 6 `.DS_Store` files tracked.
  - `.gitignore` has `.DS_Store` but files were committed before the ignore rule.
- Impact:
  - Noise in diffs; potential minor info leak (folder view preferences).
- Recommendation:
  - `git rm --cached` all `.DS_Store` files.
- Validation:
  - `git ls-files '*.DS_Store'` returns empty.

## 14. Low and Informational Findings

### [AUDIT-007] No cancellation support in GUI generation

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Reliability
- File: `Sources/WorkflowSuggesterProApp/Models/AppModel.swift`
- Location: `regenerate()` method — `Task.detached` with no stored handle
- Evidence:
  - The `isGenerating` guard prevents double-invocation but provides no way to cancel a stuck generation.
- Impact:
  - User must force-quit if generation hangs (especially with no timeouts per AUDIT-002).
- Recommendation:
  - Store the `Task` handle and provide a cancel button.

### [AUDIT-008] Undocumented environment variables

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Documentation
- File: `README.md`
- Evidence:
  - `WORKFLOWSUGGESTER_PROVIDER`, `ANTHROPIC_MODEL`, `OPENAI_MODEL` are not documented in README.
- Recommendation:
  - Add an "Environment Variables" section to README.

### [AUDIT-009] Duplicate orchestration logic

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Architecture
- File: `Sources/WorkflowSuggesterPro/main.swift` and `Sources/WorkflowSuggesterProApp/Models/AppModel.swift`
- Evidence:
  - Both contain nearly identical fetch → filter → detect → suggest → write pipelines.
- Impact:
  - Changes must be duplicated; risk of drift.
- Recommendation:
  - Extract a shared `WorkflowPipeline` service in Core.

### [AUDIT-010] Empty reports/ directory committed

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Repository hygiene
- File: `reports/`, `reports/session/`
- Evidence:
  - Contains only `.DS_Store` files; no code references this directory.
- Recommendation:
  - Remove or add to `.gitignore`.

### [AUDIT-013] `swift test` fails due to extended attributes on .build/

- Severity: Low
- Priority: P3
- Confidence: Confirmed
- Category: Reliability
- File: `.build/out/Products/Debug/WorkflowSuggesterProTests.xctest`
- Location: CodeSign step during `swift test`
- Evidence:
  - `swift test` exits with code 1: "resource fork, Finder information, or similar detritus not allowed" on the test bundle.
  - Running `xattr -cr .build` before `swift test` resolves it.
  - Likely caused by Finder/Spotlight adding extended attributes to `.build/` contents.
- Impact:
  - Tests appear broken on first run; developer must know the xattr workaround.
- Recommendation:
  - Add `xattr -cr .build` to a test helper script, or document the workaround in README.
- Validation:
  - `swift test` passes without manual intervention after fix.

### [AUDIT-011] Requires macOS 26 (Tahoe)

- Severity: Informational
- Priority: —
- Confidence: Confirmed
- Category: macOS
- File: `Package.swift`
- Evidence:
  - Platform minimum is `.macOS(.v26)` — the bleeding-edge unreleased macOS version. This is intentional for FoundationModels access.
- Impact:
  - Cannot be built or run on any shipping macOS as of this audit date context. Only compatible with developer betas.

### [AUDIT-012] No persistent state beyond Keychain and scripts

- Severity: Informational
- Priority: —
- Confidence: Confirmed
- Category: Architecture
- Evidence:
  - Preferences stored via `UserDefaults` (via `AppPreferencesStore`). API keys in Keychain. No database, no cache of AW data.
- Impact:
  - Simple and appropriate. No data corruption risk from app state.

## 15. Security Assessment

**Overall: Good.** No committed secrets, no injection vectors, no unsafe deserialization.

- API keys are stored in macOS Keychain with proper `SecItemAdd`/`SecItemUpdate`/`SecItemDelete` lifecycle.
- No secrets in source code or scripts.
- `.env` files are gitignored.
- Network calls use HTTPS for cloud APIs.
- The only concern (AUDIT-003) is generated scripts being executable by default — a usability risk, not a vulnerability.

## 16. Correctness Assessment

**Overall: Good.** Logic is straightforward and well-commented.

- JSON extraction (`CloudJSONExtraction`) uses defensive first-`[`-to-last-`]` slicing — robust against model preamble/postamble.
- Date decoding handles ActivityWatch's 6-digit fractional seconds correctly.
- RecurrenceDetector correctly groups by app+title composite key and filters empties.
- The on-device retry mechanism is bounded (2 attempts max).

## 17. Reliability and Operational Stability

- **Network timeouts:** Missing (AUDIT-002). Primary operational risk.
- **Cancellation:** Not implemented in GUI (AUDIT-007).
- **Error handling:** Comprehensive — AFK watcher failure is non-fatal; on-device model unavailability falls back to cloud; cloud failures surface clearly.
- **No background processes, daemons, or scheduled tasks.** Run-on-demand only.
- **No persistent locks, queues, or temp files** that could accumulate.

## 18. Architecture and Complexity Assessment

**Ambition–Capacity Mismatch:** None detected. The architecture is appropriately simple for a single-developer personal tool. The Core/CLI/GUI split is clean and proportional.

Minor improvement opportunity: consolidate the duplicated pipeline orchestration (AUDIT-009).

## 19. Dependency Assessment

**No external SwiftPM dependencies.** The project uses only Apple platform frameworks (Foundation, FoundationModels, Security, SwiftUI, AppKit). This is excellent for maintainability and supply-chain security.

No lock file is needed (no third-party packages).

## 20. Testing Assessment

- 3 test files covering `RecurrenceDetector`, `AWEvent` decoding, and `AFKFilter`.
- Tests use Swift Testing framework (`@Test` macro).
- Tests are well-structured with clear assertions.
- **Gap:** No tests for JSON extraction, script writing, or provider selection logic (AUDIT-005).

## 21. Documentation Assessment

- README is accurate and concise.
- Build/run commands match actual project structure.
- Missing: full environment variable reference (AUDIT-008).
- No architecture docs needed at this scale.

## 22. macOS and Apple-Specific Assessment

- No hardcoded user paths (`/Users/...`).
- Correctly uses `FileManager.urls(for: .applicationSupportDirectory)` for output.
- Keychain usage follows platform conventions.
- App bundle generation in `build_and_run.sh` is correct (Info.plist, bundle structure).
- No entitlements or sandbox configuration — appropriate for a development/personal tool.
- `NSApp.setActivationPolicy(.regular)` — Dock-visible, intentional per comment.

## 23. Shell Script Assessment

`scripts/build_and_run.sh`:
- ✅ `#!/usr/bin/env bash`
- ✅ `set -euo pipefail`
- ✅ Proper quoting throughout
- ✅ `ROOT_DIR` resolution via `BASH_SOURCE`
- ⚠️ `pkill -x "$APP_NAME"` on line 18 — kills any running instance before build. Acceptable for a dev script but worth noting.
- ⚠️ `rm -rf "$APP_BUNDLE"` — safe in context (variable is well-defined, under `$DIST_DIR`).
- No `curl | sh`, no `sudo`, no dangerous patterns.

## 24. Repository Hygiene

- `.gitignore` is comprehensive and correct.
- Committed `.DS_Store` files should be removed (AUDIT-006).
- Committed binary in `dist/` should be untracked (AUDIT-001).
- Empty `reports/` directory has no purpose (AUDIT-010).
- `archive/Icon` file — a macOS folder icon resource, harmless.

## 25. Prioritized Remediation Plan

### Stage 0 — Preserve and Validate

- No changes needed; repository is in a safe state.

### Stage 1 — Critical Stabilization

1. **Remove committed binary** (`git rm -r --cached dist/`) — AUDIT-001
2. **Add network timeouts** to all URLSession calls — AUDIT-002

### Stage 2 — Reliability Improvements

3. Change generated script permissions to 644 — AUDIT-003
4. Add cancellation support to GUI — AUDIT-007

### Stage 3 — Simplification

5. Extract shared pipeline from CLI/AppModel — AUDIT-009

### Stage 4 — Maintainability

6. Add unit tests for CloudJSONExtraction and AutomationScriptWriter — AUDIT-005
7. Document all environment variables — AUDIT-008
8. Clean up .DS_Store and reports/ — AUDIT-006, AUDIT-010

## 26. Quick Wins

1. `git rm -r --cached dist/ && git commit` — stop tracking build output
2. `git rm --cached '**/.DS_Store' && git commit` — remove tracked .DS_Store files
3. Remove empty `reports/` directory or gitignore it
4. Change `0o755` to `0o644` in `AutomationScriptWriter.swift` line 35
5. Add `timeoutIntervalForRequest: 30` to ActivityWatch URLRequests
6. Add `timeoutIntervalForRequest: 120` to LLM provider URLRequests
7. Document `WORKFLOWSUGGESTER_PROVIDER`, `ANTHROPIC_MODEL`, `OPENAI_MODEL` in README
8. Document `xattr -cr .build` workaround for test codesign failures in README

## 27. Deferred Improvements

- AFKFilter O(n×m) optimization — unlikely to matter at personal-use scale
- Shared pipeline extraction — low risk of drift at current commit frequency
- Integration tests with mock HTTP server

## 28. Unresolved Questions

1. Is the `dist/` binary intentionally committed for distribution, or was it an oversight? (`.gitignore` says oversight)
2. Is `reports/` intended for future use?
3. Should the GUI app be code-signed for distribution?

## 29. Final Recommendation

This is a clean, well-written personal tool with no critical issues. The highest-priority action is removing the committed binary from git history (or at minimum from tracking), followed by adding network timeouts to prevent hangs. The codebase is architecturally sound and appropriately simple for its scope.
