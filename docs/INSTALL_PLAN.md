# WorkflowSuggesterPro — Installation Plan for `giovanncomsiMac.localdomain`

- **Date:** 2026-09-07
- **Companion document:** [`AUDIT_REPORT.md`](AUDIT_REPORT.md) — read §6 and §7 before enabling the cloud path.
- **Status:** **NOT EXECUTED.** Every command below is proposed, awaiting authorization.
- **Repository:** `/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro`

---

## 0. Machine Preflight (measured, read-only)

| Prerequisite | Repo requirement | This machine | Status |
|---|---|---|---|
| macOS version | 26.0+ (`Package.swift`, `@available`) | **26.6.2** (25G83) | **READY** |
| Architecture | Apple Silicon | **arm64, Apple M3**, iMac `Mac15,5`, 8 cores, 16 GB | **READY** |
| Swift toolchain | tools-version 6.3 | **6.3.3** (`/usr/bin/swift`) | **READY** |
| Xcode / CLT | macOS 26 SDK | **Xcode 26.6** (17F113), `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer` | **READY** |
| Git | for the repo | 2.55.0 | **READY** |
| Disk space | ~200 MB for `.build` | **124 GB free** | **READY** |
| Repository present | — | Present, branch `master`, commit `e0b628b`, working tree clean | **READY** |
| `.build` cache | — | Present, 147 MB, valid (`swift build` → *Build complete*) | **READY** |
| `swift test` | must pass | **24/24 pass, exit 0** | **READY** |
| `xattr` cleanup | README suggests `xattr -cr .build` | Only `com.apple.provenance` xattrs; **zero** FinderInfo/ResourceFork. Not needed. | **READY (no action)** |
| Apple Intelligence | on-device path | `SystemLanguageModel.default.availability` → **`.available`** (verified with a throwaway probe, since deleted). `modelmanagerd`, `generativeexperiencesd`, `intelligenceplatformd` all running; opt-in flag set. | **READY** |
| **ActivityWatch app** | required | **Not installed.** No `/Applications/ActivityWatch.app`, no `aw-*` binaries on `PATH`. | **MISSING — BLOCKER** |
| **ActivityWatch server** | `localhost:5600` | **Nothing listening.** `curl` → HTTP 000. | **MISSING — BLOCKER** |
| **`aw-watcher-window`** | required | Not running (app absent) | **MISSING — BLOCKER** |
| `aw-watcher-afk` | optional (graceful degradation) | Not running | **OPTIONAL** |
| **Rosetta 2** | needed only for the stable x86_64 AW build | **Not installed** (`arch -x86_64` → *Bad CPU type*) | **MISSING (conditional)** |
| Homebrew | install method | **6.0.22** at `/opt/homebrew` | **READY** |
| `ANTHROPIC_API_KEY` | optional | **NOT SET** | **OPTIONAL** |
| `OPENAI_API_KEY` | optional | **NOT SET** | **OPTIONAL** |
| `WORKFLOWSUGGESTER_*` | optional | All **NOT SET** | **OPTIONAL** |
| Keychain entry | optional (GUI) | No item for service `WorkflowSuggesterPro` | **OPTIONAL** |
| Output directory | auto-created | `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/` exists and is **empty** | **READY** |
| Existing app bundle | — | No `dist/`, no `/Applications/WorkflowSuggester Pro.app` | **READY (clean)** |
| Duplicate installs | — | **None.** Only the repo and one historical audit copy under `~/Reports/RepositoryAudits/`. | **READY** |
| LaunchAgents | must not exist yet | **None** reference this project | **READY** |
| AW Accessibility permission | needed for window titles | Not granted (app absent) | **USER VERIFICATION REQUIRED** |

### Gap analysis

**Mandatory blockers (prevent operation, not compilation):**

1. ActivityWatch not installed.
2. ActivityWatch server not running on `localhost:5600`.
3. `aw-watcher-window` not running.
4. macOS Accessibility permission for ActivityWatch not granted (window titles come back empty without it).

**Nothing blocks compilation.** The project already builds and tests green.

**Optional capabilities:**

- Cloud fallback (Anthropic / OpenAI keys) — **not needed**; the on-device model is available.
- GUI app bundle via `scripts/build_and_run.sh` — optional, after the CLI is validated.
- Rosetta 2 — required only if you choose the stable x86_64 ActivityWatch build.

**Security decisions for you to make deliberately (do not let these get configured silently):**

- **D1 — Cloud path.** Configuring an API key means an on-device failure will silently transmit truncated window titles to a third party (AUDIT_REPORT §7, SEC-07). Leaving keys unset makes such a failure loud and local. **Recommendation: leave the cloud path unconfigured.**
- **D2 — Rosetta 2.** A permanent, Apple-supplied system component. Avoidable by using the arm64 prerelease.
- **D3 — Generated scripts.** They contain unvalidated model output and the writer uncomments `# `-prefixed lines (SEC-01, SEC-02). Read every script before running it, and remember that `0644` does not stop `sh script.sh`.

---

## Stage 0 — Preconditions

Must be true before starting:

- [ ] Repository at `/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro`, clean tree — **already true**.
- [ ] Xcode 26.6 + Swift 6.3.3 — **already true**.
- [ ] macOS 26.6.2, Apple Silicon, Apple Intelligence enabled — **already true**.
- [ ] You have decided **D1** (cloud path yes/no) and **D2** (Rosetta vs arm64 prerelease).
- [ ] Nothing else is bound to port 5600 — **verified free**.

Re-confirm the baseline (all read-only, ~2 s):

```bash
cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro && \
sw_vers -productVersion && uname -m && swift --version | head -1 && \
git -C . status --short && echo "baseline OK"
```

---

## Stage 1 — Dependencies

**Nothing to install for the build.** Zero third-party SwiftPM packages; every framework used ships with macOS 26. Swift 6.3.3 and Xcode 26.6 are present. **Skip to Stage 2.**

Confirm only:

```bash
swift build --package-path /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro 2>&1 | tail -3
```

Expect: `Build complete!`

---

## Stage 2 — ActivityWatch

This is the only real installation work. Pick **one** option.

### Option A — Stable 0.13.2 via Homebrew *(RECOMMENDED)*

Reproducible, inspectable, cleanly uninstallable, and a released stable version. Costs one Rosetta 2 install because the 0.13.2 macOS build is x86_64.

**A1. Install Rosetta 2** — *system change: adds Apple's x86_64 translation layer permanently. Non-destructive, no reboot, cannot be cleanly uninstalled.*

```bash
softwareupdate --install-rosetta --agree-to-license
```

Validate:

```bash
/usr/bin/arch -x86_64 /usr/bin/uname -m   # expect: x86_64
```

**A2. Inspect the cask before installing** (read-only — never install a cask you have not read):

```bash
brew info --cask activitywatch
brew cat --cask activitywatch
```

**A3. Install:**

```bash
brew install --cask activitywatch
```

Validate:

```bash
ls -d /Applications/ActivityWatch.app && \
/usr/bin/codesign -dv /Applications/ActivityWatch.app 2>&1 | head -3
```

### Option B — Native arm64 prerelease *(no Rosetta)*

Official macOS builds became arm64-only starting with the `v0.14.0bX` prereleases. Native on M3, but a **beta**, and updates are manual.

1. Open <https://github.com/ActivityWatch/activitywatch/releases> and download the newest `activitywatch-v0.14.0bX-macos-arm64.dmg`.
2. Verify the checksum against the release page before opening it.
3. Mount, drag `ActivityWatch.app` to `/Applications`, eject.

> Deliberately not using `curl … | sh` or any piped remote installer. Both options above are inspectable and reproducible.

### A/B common — start it and grant permissions

**S1. Launch:**

```bash
open -a ActivityWatch
```

**S2. Grant Accessibility permission (manual, unavoidable).** `aw-watcher-window` cannot read window titles without it — the app runs but every title comes back empty, so `RecurrenceDetector` finds nothing:

> System Settings → Privacy & Security → **Accessibility** → enable **ActivityWatch**
> (if prompted separately, also enable it under **Screen & System Audio Recording**)

Then quit and relaunch ActivityWatch so the watcher picks up the grant.

**S3. Validate the server and both watchers:**

```bash
curl -s -m 5 http://localhost:5600/api/0/info | head -c 300; echo
pgrep -fl "aw-qt|aw-server|aw-watcher-window|aw-watcher-afk"
```

**S4. Validate the buckets the app actually looks for** — it prefix-matches `aw-watcher-window_` and `aw-watcher-afk_`:

```bash
curl -s -m 5 http://localhost:5600/api/0/buckets/ | python3 -c \
'import json,sys; [print(k) for k in json.load(sys.stdin).keys()]'
```

Expect at least one `aw-watcher-window_<hostname>`. If more than one appears, note AUD-06: bucket choice is non-deterministic between runs.

**S5. Accumulate data.** `RecurrenceDetector` needs an `app::title` pair seen **≥ 4 times**. A fresh install has no history — **use the Mac normally for a few hours to a day before expecting suggestions.** Check progress:

```bash
BUCKET=$(curl -s http://localhost:5600/api/0/buckets/ | python3 -c \
'import json,sys; print(next(k for k in json.load(sys.stdin) if k.startswith("aw-watcher-window_")))')
curl -s "http://localhost:5600/api/0/buckets/$BUCKET/events?limit=5" | head -c 500; echo
```

Confirm the events carry non-empty `"title"` values — empty titles mean the Accessibility grant in S2 did not take.

**Data stays local.** ActivityWatch's own server binds to localhost; do not enable any of its sync or cloud features.

---

## Stage 3 — Repository Build

Already validated on this machine — no changes needed. Simplest supported path:

```bash
cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro
swift build
swift test
```

Expect `Build complete!` and `24 tests … passed`.

> **Do not** run `xattr -cr .build`. It is unnecessary here (only `com.apple.provenance` attributes are present, and those do not cause the codesign detritus error). If a future toolchain update ever does produce that failure, `.build` is the correct scope — it is gitignored and fully regenerable — and nothing wider should be touched.
>
> **Note:** `swift test` writes to and deletes files in your real `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/` (SEC-08). Harmless, but that is why the directory already exists.

---

## Stage 4 — LLM Configuration

### Local-first (RECOMMENDED — no action required)

Apple Intelligence is **available** on this Mac. The default provider mode (`.onDeviceFirst` / no `WORKFLOWSUGGESTER_FORCE_CLOUD`) runs entirely on-device: nothing leaves the machine, and no API key is needed. **This is the complete configuration. Stop here unless you have a specific reason not to.**

Re-verify at any time:

```bash
cat > /tmp/fm_probe.swift <<'PROBE'
import FoundationModels
if #available(macOS 26.0, *) {
    switch SystemLanguageModel.default.availability {
    case .available: print("FM: available")
    case .unavailable(let r): print("FM: unavailable -> \(r)")
    }
}
PROBE
swift /tmp/fm_probe.swift; rm -f /tmp/fm_probe.swift
```

### Optional cloud fallback — only if you accept decision D1

> Configuring a key means that when the on-device model throws a `FoundationModelsSuggestionError`, the app **automatically** sends app names and 40-character-truncated window titles to Anthropic or OpenAI, with no confirmation prompt. See AUDIT_REPORT §7.

**GUI (Keychain — the correct place).** Launch the app, open **Settings → Cloud API Keys**, paste the key, click **Save**. It is stored via `SecItemAdd` under service `WorkflowSuggesterPro`. Never type a key into a source file or a committed `.env`.

**CLI (environment).** The CLI reads only the process environment and **never** the Keychain — the two entry points do not share key storage.

For a single run, without touching shell history or any rc file (note the leading space, which `HISTCONTROL`/`setopt histignorespace` uses to skip the line):

```bash
 ANTHROPIC_API_KEY='<ANTHROPIC_API_KEY>' WORKFLOWSUGGESTER_FORCE_CLOUD=1 \
   swift run --package-path /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro WorkflowSuggesterPro
```

For persistent CLI use, **recommendation (the repo does not implement this itself):** store the key once in the login Keychain and read it at call time, rather than writing it into `~/.zshrc`:

```bash
# store once (interactive prompt; -w without a value asks for input)
security add-generic-password -a "$USER" -s WorkflowSuggesterPro-CLI-Anthropic -w

# use per invocation
 ANTHROPIC_API_KEY="$(security find-generic-password -a "$USER" -s WorkflowSuggesterPro-CLI-Anthropic -w)" \
   swift run --package-path /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro WorkflowSuggesterPro
```

Note `WORKFLOWSUGGESTER_FORCE_CLOUD` is a **presence** check — `=0` and `=false` still force cloud. Unset it to return to on-device.

---

## Stage 5 — First Launch (CLI first)

```bash
cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro
swift run WorkflowSuggesterPro
```

What to expect, in order:

1. `Generating on-device with Apple Intelligence…`
2. 30–90 s of on-device generation (no progress output during this).
3. A list of recurring workflows, then suggestion blocks, then the written script paths.

Likely early outcomes:

| Output | Meaning | Action |
|---|---|---|
| `No aw-watcher-window_* bucket found…` | AW not running or watcher disabled | Redo Stage 2 S1/S3 |
| `No recurring workflows found in the last 14 days` | AW running but under 4 occurrences of any `app::title` — **expected on a fresh install** | Use the Mac normally, retry later |
| `AFK bucket unavailable (…); using unfiltered window events.` | Non-fatal; `aw-watcher-afk` off | Optional: enable it in the AW tray |
| `On-device unavailable (…). Falling back to cloud…` | Apple Intelligence stopped being available | With no key set this fails loudly — the intended safe outcome |

---

## Stage 6 — Functional Validation

```bash
cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro

# 1. app starts / builds
swift build 2>&1 | tail -1

# 2. ActivityWatch reachable
curl -s -m 5 -o /dev/null -w "AW: HTTP %{http_code}\n" http://localhost:5600/api/0/info

# 3. events readable, with real titles
BUCKET=$(curl -s http://localhost:5600/api/0/buckets/ | python3 -c \
'import json,sys; print(next(k for k in json.load(sys.stdin) if k.startswith("aw-watcher-window_")))')
echo "bucket: $BUCKET"
curl -s "http://localhost:5600/api/0/buckets/$BUCKET/events?limit=3" | head -c 400; echo

# 4-7. pattern analysis + provider + suggestion, in one run
swift run WorkflowSuggesterPro

# 8. scripts written to the expected directory
ls -la "$HOME/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/"

# 9. scripts are NOT executable and were NOT run
stat -f "%Sp %N" "$HOME/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/"*.sh
```

Expected: `-rw-r--r--` on every script — **no `x` bits**.

**10. Confirm the correct provider was used.** The CLI does not print the source; the GUI shows an "On-device" / "Cloud (…)" badge. From the CLI, confirm negatively — with no API key set, any cloud attempt fails with `Missing ANTHROPIC_API_KEY or OPENAI_API_KEY`. A successful run with no key set is proof the on-device path ran.

**11. Read a generated script before running anything:**

```bash
cat "$HOME/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/"*.sh
```

Check for anything you did not expect — `rm`, `curl`, `sudo`, unfamiliar paths, redirection to a network host. The app validates none of this (SEC-01), and any `# ` prefix the model wrote has been stripped away (SEC-02).

---

## Stage 7 — GUI App Bundle *(optional, only after Stage 6 passes)*

`scripts/build_and_run.sh` was inspected line by line (AUDIT_REPORT §8) and is **safe**: no `sudo`, no network, no signing, no LaunchAgent, and its single `rm -rf` is bounded to `<repo>/dist/WorkflowSuggester Pro.app`. It does have side effects — it kills any running instance, rebuilds `dist/`, and **launches the app**.

```bash
cd /Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro
./scripts/build_and_run.sh
```

The bundle is **unsigned and ad-hoc**, so Gatekeeper will likely need a manual first-launch approval (right-click → Open, or System Settings → Privacy & Security → *Open Anyway*).

The GUI adds over the CLI: adjustable lookback and threshold, a provider picker, **Keychain key storage**, a cancel button, a source badge, and a script list with Reveal in Finder.

> Reminder: the GUI reads keys **only** from the Keychain. Exporting `ANTHROPIC_API_KEY` in a terminal has no effect on the Dock-launched app.

---

## Stage 8 — Persistence / Daily Use

**Recommendation: do not automate this yet.** The app is on-demand by design — no daemon, no timer, no polling (AUDIT_REPORT §3). The natural progression is manual success → repeatable → stable → only then automate. You have not yet had a single successful run.

**Do not create a LaunchAgent.** No unattended startup automation is proposed here.

The one thing worth making persistent is ActivityWatch itself, since the app is useless without history. Enable it inside ActivityWatch's own tray preferences ("Start at login") rather than hand-writing a plist — that keeps a single owner for the plist and makes it reversible from the same UI.

If, after several weeks of manual use, you want the app more convenient, the lightest option is a Dock/Spotlight-launchable bundle from Stage 7 — no background process, no plist, no new moving parts.

**Freeze point:** once Stage 6 passes and you have reviewed one generated script, the installation is **done**. Do not add scheduling, menu-bar autostart, or notification wiring in the same pass.

---

## Stage 9 — Rollback / Uninstall

Ordered least to most destructive. Each step is independent.

**1. Generated scripts** *(your data — review before deleting)*

```bash
ls -la "$HOME/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/"
# then, if you are sure:
rm -rf "$HOME/Library/Application Support/WorkflowSuggesterPro"
```

**2. GUI app bundle**

```bash
pkill -x WorkflowSuggesterProApp 2>/dev/null || true
rm -rf "/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro/dist"
```

**3. Build artifacts** *(regenerable — `swift build` rebuilds them)*

```bash
rm -rf "/Users/giovannini.eduardogmail.com/Automation/WorkflowSuggesterPro/.build"
```

**4. GUI preferences (UserDefaults)**

```bash
defaults delete local.workflowsuggesterpro.app WorkflowSuggesterPro.preferences 2>/dev/null || \
defaults delete local.workflowsuggesterpro.app 2>/dev/null || true
```

**5. Keychain API keys** *(only if you stored them in Stage 4)*

```bash
security delete-generic-password -s WorkflowSuggesterPro -a anthropic_api_key 2>/dev/null || true
security delete-generic-password -s WorkflowSuggesterPro -a openai_api_key   2>/dev/null || true
security delete-generic-password -s WorkflowSuggesterPro-CLI-Anthropic       2>/dev/null || true
```

**6. Environment variables** — nothing to undo. None were set, and this plan writes none to any rc file. If you added any yourself, remove those lines from `~/.zshrc` / `~/.zprofile`.

**7. ActivityWatch** *(only if you no longer want it — it is independently useful and holds your history)*

```bash
# Option A (Homebrew):
brew uninstall --cask activitywatch
# Option B (manual .dmg install):
rm -rf "/Applications/ActivityWatch.app"

# its own data, separate from this project — delete only if you want the history gone:
ls -la "$HOME/Library/Application Support/activitywatch"
```

Then revoke the Accessibility grant: System Settings → Privacy & Security → Accessibility → remove ActivityWatch.

**8. Rosetta 2** — cannot be cleanly uninstalled and is harmless to leave. No rollback offered.

**Not touched by any step above:** the repository source, git history, `docs/`, or any unrelated user data.

---

## Validation Checklist

**Preflight**
- [ ] `sw_vers` ≥ 26.0 — *already true (26.6.2)*
- [ ] `uname -m` = `arm64` — *already true*
- [ ] `swift --version` ≥ 6.3 — *already true (6.3.3)*
- [ ] Apple Intelligence probe → `available` — *already true*
- [ ] Repo tree clean — *already true*

**Stage 2 — ActivityWatch**
- [ ] Rosetta 2 installed *(Option A only)* — `arch -x86_64 uname -m` → `x86_64`
- [ ] `/Applications/ActivityWatch.app` exists
- [ ] `curl http://localhost:5600/api/0/info` returns HTTP 200
- [ ] `aw-watcher-window` process running
- [ ] Accessibility permission granted to ActivityWatch
- [ ] A bucket named `aw-watcher-window_<hostname>` exists
- [ ] Sample events carry **non-empty** `title` values
- [ ] *(optional)* `aw-watcher-afk` running

**Stage 3 — Build**
- [ ] `swift build` → `Build complete!`
- [ ] `swift test` → 24/24 pass
- [ ] `xattr -cr .build` **not** run (unnecessary)

**Stage 4 — LLM**
- [ ] On-device model confirmed available
- [ ] Decision D1 made; keys configured **only** if you accepted cloud egress
- [ ] No API key written into any source file, `.env`, or rc file

**Stage 5/6 — Function**
- [ ] `swift run WorkflowSuggesterPro` completes without error
- [ ] Recurring workflows listed (or the "no recurring workflows" message, if history is still thin)
- [ ] At least one suggestion printed
- [ ] `.sh` files present in `~/Library/Application Support/WorkflowSuggesterPro/GeneratedAutomations/`
- [ ] Every script is `-rw-r--r--` (no `x` bit)
- [ ] No script executed automatically — no unexpected side effects on the machine
- [ ] At least one script read end to end and judged safe **before** running it

**Stage 7 — GUI (optional)**
- [ ] `./scripts/build_and_run.sh` builds and launches
- [ ] Dashboard shows the source badge and script list
- [ ] Gatekeeper approval granted once

**Stage 8 — Restraint**
- [ ] **No LaunchAgent created**
- [ ] ActivityWatch autostart (if wanted) enabled from its own preferences, not a hand-written plist
- [ ] Installation frozen — no scheduling or notification work added in this pass

---

## Stop Conditions

**Done when:** ActivityWatch is running with a populated window bucket, `swift run WorkflowSuggesterPro` completes on the on-device path, scripts land in the expected directory at `0644`, and you have read one of them.

**Do not add in this pass:** LaunchAgents or background scheduling; cloud API keys (unless D1 was a deliberate yes); code changes to fix the audit findings; a menu-bar autostart; NotebookLM re-syncing; anything from `docs/REPOSITORY_AUDIT.md`'s recommendation list.

**Freeze the system** once the Stage 6 checklist is fully ticked. Findings SEC-01, SEC-02, and SEC-07 are code changes, not installation steps — they belong to a separate, later decision.
