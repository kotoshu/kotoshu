# 61 — Editor & CI ecosystem

Promotes the editor-integration portions of T6.1 / T6.3 in
`TODO.impl/56-t4-t5-t6-quality-architecture-ecosystem.md` into a
promotable plan.

## Goal

Kotoshu available in every major editor and every major CI system
without users writing their own glue. Each integration is a **thin
adapter** over either:

- The LSP server (plan 60) — for interactive editing.
- The CLI (`kotoshu check`) — for batch / CI use.

The integrations live in **separate repos** under `kotoshu/`, per the
five-repo workspace model. The library gem stays focused on
spell-checking; the integrations ship their own release cadence.

## Why

The CLI is shipped. The LSP server (plan 60) is the editor surface.
What's missing is the **adapter packaging** that makes a user say "I
installed it in 30 seconds":

- VS Code users install an extension, not a binary + JSON config.
- Vim users want a one-line plugin manager entry, not a 50-line `lsp`
  config.
- CI users want a one-step action / template, not a multi-line script.
- Pre-commit framework users want a single repo entry, not a wrapper.

This is the difference between "available" and "adopted". Each adapter
is small — the heavy lifting is in the library — but the user-facing
convenience is the leverage point.

## Tasks

### Track A — Editor extensions (LSP-backed)

1. **`kotoshu/vscode-kotoshu`.** VS Code / VSCodium extension.
   - Bundles the LSP server as a recommended dependency (auto-install
     on first activation if missing, with user consent).
   - Adds a single `kotoshu.enabled` setting (default true) plus
     pass-through settings mirroring the LSP server's configuration
     keys (plan 60, step 12).
   - Contributes command palette actions: `Kotoshu: Set Up Language`,
     `Kotoshu: Add Word to Personal Dictionary`, `Kotoshu: Check
     Workspace`.
   - Activation on `onLanguage:*` for the supported `languageId`s.
2. **`kotoshu/kotoshu-nvim`.** Neovim plugin (Lua).
   - Built-in LSP client config — `require('kotoshu').setup({})`
     wires `vim.lsp.start({ name = 'kotoshu', cmd = { 'kotoshu-lsp' } })`.
   - `personal_dict` user command wraps the LSP code action.
   - Defaults that work without configuration; override hook for
     power users.
3. **`kotoshu/vim-kotoshu`.** Vim 8+ / Neovim (legacy) plugin for
   users not on Neovim's built-in LSP.
   - Wraps [ALE](https://github.com/dense-analysis/ale) as a linter
     definition; ALE handles async + location list.
   - Ships a fallback synchronous `:KotoshuCheck` that shells out to
     the CLI for non-LSP users.
4. **Emacs.** Recipe for `lsp-mode` and `eglot` documented in the LSP
   server's README; no separate repo needed (Emacs users expect to add
   entries to `lsp-language-id-configuration` themselves).
5. **JetBrains.** Document the LSP connector path (Settings → Language
   Servers → add `kotoshu-lsp`). No separate plugin unless we want
   custom intention UI; defer until LSP connector gaps are observed.
6. **Sublime Text, Helix, Zed.** Document LSP connector config in the
   README; no separate repo.

### Track B — Git pre-commit hooks

7. **`kotoshu/pre-commit-kotoshu`.** Hook for the
   [pre-commit](https://pre-commit.com) framework.
   - Entry in the central `pre-commit` hooks catalog so users add three
     lines to `.pre-commit-config.yaml`.
   - Runs `kotoshu check --format sarif` on staged hunks; fails the
     commit when errors are found.
   - Honors `.kotoshu.yml` for ignored words and file globs.
8. **Plain git hook script.** Ship a `scripts/install-git-hook.sh` in
   the gem (or LSP repo) that writes `.git/hooks/pre-commit` calling
   `kotoshu check`. Documented in the main README.

### Track C — CI integrations

9. **`kotoshu/action-kotoshu`.** GitHub Action published on the
   Marketplace.
   - `uses: kotoshu/action-kotoshu@v1` with `files:` and `language:`
     inputs.
   - Caches `$XDG_CACHE_HOME/kotoshu/` across runs via
     `actions/cache`.
   - Runs `kotoshu setup` on first run; `kotoshu check --format sarif`
     thereafter.
   - Uploads the SARIF report via `github/codeql-action/upload-sarif`
     so results surface in the repo's Security tab.
10. **GitLab CI template.** Published in the GitLab CI templates
    catalog; one-line `include:` for GitLab users.
11. **CircleCI / Jenkins / Drone.** Documented snippets in the README;
    no separate repo unless demand warrants.
12. **Docker image.** `kotoshu/ci` image with the gem + a
    pre-warmed en/de/es/fr/pt/ru dictionary cache baked in. Used by
    CI integrations to avoid cold downloads.

### Track D — Documentation

13. **Editor install matrix** on `kotoshu.github.io`. One row per
    editor, with install instructions and a screenshot / GIF.
14. **CI integration matrix.** One row per CI system, with snippet and
    expected output.
15. **Migrating-from-LTeX / -LanguageTool guide.** Direct comparison:
    features, performance, configuration parity.

## Acceptance criteria

Per adapter:

- The README's install instructions work end-to-end on a clean machine.
- A misspelled word in a sample repo triggers a diagnostic in < 1 s
  (editor adapters) or fails the CI run (CI adapters).
- The adapter honors `.kotoshu.yml` (ignored words, file globs).
- Smoke test in the adapter's own CI spins up the editor / CI scenario
  and asserts the expected behavior.

Across adapters:

- All adapters reference the LSP server or the CLI; **none** duplicate
  spell-checking logic.
- All adapters live in their own repo under `kotoshu/`.
- `kotoshu.github.io` editor & CI matrices cover every adapter that
  ships.

## Dependencies

- **Blocked by:**
  - `60-lsp-server` — every interactive editor adapter depends on it
  - `02-cli-unification` — every CI adapter depends on a stable CLI
- **Blocks:** `11-release-v1` (ecosystem is what makes v1 land softly)
- **Cross-repo:** many new repos under `kotoshu/` (see tasks).
- **Promotes from:** T6.1, T6.3 in `56-t4-t5-t6-quality-architecture-ecosystem.md`

## Out of scope

- Reimplementing spell-checking inside any adapter. Adapters are thin.
- A desktop GUI app for dictionary curation (defer to T6.3 in plan 56
  — needs its own plan if pursued).
- Mobile editor integrations (Working Copy, Textastic) — low demand;
  revisit if asked.
- AI assistant integrations (Copilot, Cursor) — those read LSP
  diagnostics natively, so once the LSP server is up, they get
  Kotoshu for free. Document but don't ship.

## Risks

- **Editor churn.** VS Code breaks APIs every release; pin a Node
  version range and test on the latest two VS Code releases.
- **Pre-commit framework politics.** The central hook catalog has
  review latency. Mirror the hook in `kotoshu/pre-commit-kotoshu` and
  document the local-repo path as the primary install until catalog
  inclusion lands.
- **CI cold-start cost.** Downloading dictionaries on every CI run is
  slow. The `kotoshu/ci` Docker image (task 12) is the fix; without
  it, CI integrations feel sluggish.

## Status

_Pending._ Track A and Track B can ship in parallel; Track C depends on
the SARIF output being stable (plan 32 — shipped in 0.3).
