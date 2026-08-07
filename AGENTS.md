# Repository layout

Keep this personal Swift/macOS project simple and predictable.

## Top-level folders

| Folder | Purpose |
|--------|---------|
| `Sources/` | Application code (SwiftPM equivalent of `src/`; do not rename) |
| `Tests/` | Tests only (SwiftPM convention; do not rename) |
| `scripts/` | Runnable helpers (`.sh`, `.zsh`, `.command`) |
| `config/` | Non-secret settings (create when needed) |
| `data/` | CSV, Excel, exports, raw inputs (`data/raw`, `data/processed` if helpful) |
| `assets/` | Images, icons, logos |
| `docs/` | Markdown guides, design notes |
| `docs/prompts/` | AI prompt files |
| `archive/` | Obsolete files we are not deleting yet |

## Root

Root should only contain: `README.md`, `AGENTS.md`, `.gitignore`, and toolchain files (`Package.swift`, etc.).

Build outputs (`.build/`, `dist/`) stay gitignored — do not treat them as source.

## Rules

1. Prefer **move** over copy; prefer editing existing files over creating new ones.
2. Do not invent new top-level folders without asking first.
3. No filename versioning (`Foo_v1.0.md` → `docs/foo.md`; old copy to `archive/` if unsure).
4. Merge duplicate folders into the canonical English names above.
5. Never commit secrets (`.env`, API keys, keychain dumps).
6. After moves, fix broken paths so builds still work.
7. Do not delete unless clearly a duplicate; otherwise move to `archive/`.
