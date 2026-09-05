# 81 — Editor reach: VS Code extension + pre-commit

> Supersedes the unshipped parts of
> [61-editor-ecosystem.md](61-editor-ecosystem.md). Status
> correction: kotoshu-lsp 0.1.0 (plan 60), kotoshu-server 0.1.0 +
> SDKs (plan 64, partial), and action-kotoshu v1 shipped during the
> 2026-09 campaign; what remains is the editor package and the
> pre-commit hook.

## Context

The LSP server exists (`kotoshu-lsp` gem) but nothing delivers it
into editors. The generic-LSP path requires manual config most
users never do. VS Code via a marketplace extension is the single
highest-leverage editor surface. pre-commit is where CI-minded
Python/Go shops hook spellchecking.

## Track A — `kotoshu-vscode` (new repo)

- Scaffold: TypeScript extension, `vscode-languageclient`, no
  bundling surprises (esbuild), `package.json` contributes
  `kotoshu.languageTool` (document selectors: markdown, asciidoc,
  plaintext, code comments opt-in later).
- Server discovery order: `kotoshu-lsp.serverPath` setting →
  `bundle exec kotoshu-lsp` in workspace → global `kotoshu-lsp` →
  actionable error message with install command (no silent
  failure).
- Features v0.1: publish diagnostics on open/change/save;
  suggestions as code actions; personal-dictionary add action
  (server command if supported, else documented).
- Repo: `kotoshu/kotoshu-vscode`, CI (build + `vscode-test` smoke
  against a fixture workspace with a deliberate misspelling),
  LICENSE BSD-2-Clause, README with GIF slot.
- Packaging: `vsce package` produces a .vsix in CI artifacts.
  **Marketplace publish is owner-gated** (needs publisher PAT);
  Open VSX after that.

## Track B — pre-commit hook

- `.pre-commit-hooks.yaml` living where the hook can `gem install`
  or reuse a bundled environment. Evaluate: hook id
  `kotoshu-spell` running `kotoshu check` (requires Ruby+gem —
  document honestly), vs a container hook (`language: docker_ruby`
  via the published image). Ship the honest one with clear docs;
  note the wasm client as the future zero-Ruby path.
- Placement: `action-kotoshu` repo (CI-adjacent) or the gem repo
  (ships with the tool). Prefer the **gem repo** — the hook file
  documents itself beside the CLI it calls.

## Phases

A1 scaffold → A2 discovery + diagnostics → A3 code actions + smoke
CI → B1 hook + docs → B2 (owner) marketplace publish.

## Owner gates

- Marketplace publish (Track A final step).
- Open VSX mirror.

## Status

**Pending.**
