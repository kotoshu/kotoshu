# 60 — LSP server (`kotoshu-lsp`)

Expands T6.1 in `TODO.impl/56-t4-t5-t6-quality-architecture-ecosystem.md`
into a promotable plan with concrete acceptance criteria.

## Goal

A Language Server Protocol implementation that ships Kotoshu diagnostics
into every editor with LSP support — VS Code, Neovim, Emacs (`lsp-mode` /
`eglot`), JetBrains (via the LSP connector), Sublime Text (LSP package),
VSCodium, Helix, Zed. One server, every editor.

The server is a **separate gem** (`kotoshu-lsp`), per the five-repo
workspace model — it depends on `kotoshu` but ships its own release
cadence. The library gem stays focused on spell-checking; the LSP gem
holds the editor-facing surface.

## Why

A spellchecker reaches daily users through their editor, not through a
CLI they remember to run. Today Kotoshu's reach is bounded by:

- The CLI is a manual, batch-style invocation. Real users want inline
  squiggly underlines and one-keystroke fixes.
- SARIF / JSON output targets CI/CD pipelines, not interactive editing.
- The Hunspell lineage has no editor story; LanguageTool's LSP server
  (`ltex-ls`) is the de-facto incumbent. Kotoshu needs parity.

LSP is the single highest-leverage move because:

- **One server, N editors.** Implement once, every LSP-capable editor
  picks it up.
- **Reusable infrastructure.** All the heavy lifting (document parsing,
  suggestion generation, language detection, semantic reranking) is
  already in the library. The LSP server is a thin protocol adapter.
- **Compound value with semantic path.** ONNX reranking (plan 05) shows
  its worth when suggestions are surfaced inline, where users actually
  pick them.

## Tasks

### Phase 1 — Minimum viable diagnostics

1. **New repo `kotoshu/kotoshu-lsp`.** Skeleton gemspec depending on
   `kotoshu` and an LSP library. Candidate LSP libraries to evaluate:
   - `language_server-protocol` (TypeScript-style typed protocol in Ruby)
   - Roll a minimal JSON-RPC + LSP framing layer ourselves
   Pick one and document the choice in the gem README.
2. **stdio transport.** LSP servers communicate over stdio JSON-RPC.
   Implement the framing (`Content-Length: N\r\n\r\n{json}`), the
   `initialize` / `initialized` / `shutdown` / `exit` handshake, and
   `textDocument/didOpen`, `textDocument/didChange`,
   `textDocument/didClose`.
3. **Diagnostics on save (`textDocument/publishDiagnostics`).** Wire
   `Kotoshu.check_file` (or `Kotoshu.check(text, language:)`) into a
   document-changed handler. Map `DocumentResult#errors` to
   `LSP::Diagnostic[]` with `range`, `message`, `severity = warning`,
   `source = "kotoshu"`, and `codeActions` listing the top-N
   suggestions.
4. **Per-language resource resolution.** Each open document resolves
   its language via `Kotoshu.detect_language` (or `languageId` from the
   editor). The server calls `Kotoshu.resolve(language: lang)` — on
   `ResourceNotSetupError`, send a `window/showMessage` request asking
   the user to run `kotoshu setup <lang>` (or, with user consent,
   trigger it server-side via `Kotoshu.setup`).
5. **Document-format awareness.** Use `Kotoshu::Documents::*`
   (`plain_text_document`, `markdown_document`, `asciidoc_document`)
   based on the file extension or `languageId`. Errors carry
   AST-derived positions; map those back to LSP `Position`s.

### Phase 2 — Interactive fixes

6. **Code actions (`textDocument/codeAction`).** For each diagnostic,
   emit one `CodeAction` per suggestion: "Change to 'hello'", "Add
   'helo' to personal dictionary", "Ignore in this project".
   Selecting a fix applies a `WorkspaceEdit` with a single
   `textDocument/edits` entry.
7. **Hover (`textDocument/hover`).** On a flagged word, hover shows the
   full suggestion list with semantic-similarity scores (when the
   ONNX path is enabled) and frequency rank.
8. **Personal dictionary integration.** "Add to personal dictionary"
   calls `Kotoshu::PersonalDictionary#add(word)`; subsequent
   diagnostics drop the word for the current user. Stored under
   `$XDG_CONFIG_HOME/kotoshu/personal-dict.txt` (see `Kotoshu::Paths`).
9. **Project-level configuration.** Read `.kotoshu.yml` from the
   workspace root (already supported via `Kotoshu::ProjectConfig`):
   ignored words, file globs, default language, hint language list.

### Phase 3 — Performance and UX

10. **On-type diagnostics with debounce.** Default 500ms after the last
    keystroke; configurable. Long documents must not re-check
    unmodified regions — use `textDocument/didChange`'s
    `contentChanges` range to scope re-analysis where the document
    format supports it (plain text: re-check the line; Markdown /
    AsciiDoc: re-check the enclosing block).
11. **Background model warm.** When semantic mode is enabled, call
    `OnnxModel#preload` on `initialize` so the first diagnostic push
    isn't delayed by the 4 GB model load.
12. **Configuration via LSP `workspace/didChangeConfiguration`.** Mirror
    the CLI flags: `language`, `model` (`hunspell` | `fasttext` |
    `hybrid`), `offline`, `personalDictionary`, `ignoredWords`.
13. **Trace logging.** LSP servers are notoriously hard to debug.
    Implement `$/setTrace` and write a per-session log under
    `$XDG_CACHE_HOME/kotoshu-lsp/<pid>.log` with rotation.

### Phase 4 — Packaging

14. **Executable `kotoshu-lsp`.** Installs with `gem install kotoshu-lsp`
    (pulls in `kotoshu` transitively). Editor config snippets in the
    README point at this binary.
15. **Server capabilities advertisement.** Declare exactly the
    capabilities implemented in phases 1–3 so editors don't send
    unsupported requests.
16. **Smoke-test harness.** Spin up the server as a subprocess, drive
    it with a scripted LSP client over stdio, assert diagnostics
    arrive. Add to CI.

## Acceptance criteria

- `gem install kotoshu-lsp && kotoshu-lsp` starts a server that
  answers `initialize` within 200 ms.
- Opening a Markdown file with a misspelling in VS Code (Neovim,
  Emacs, JetBrains) shows a yellow squiggle within 500 ms of save.
- Code actions appear in the editor's quick-fix menu; applying the
  top suggestion rewrites the document.
- After `Add to personal dictionary`, the same word no longer
  flags on subsequent saves (without restarting the server).
- Memory ceiling: a single open document does not exceed 250 MB
  resident (without ONNX) / 1.5 GB (with ONNX hybrid).
- Smoke-test harness runs in CI and fails on regression.

## Dependencies

- **Blocks:** `11-release-v1` (LSP is the headline v1 feature)
- **Blocked by:**
  - `02-cli-unification` — clean library API surface to wrap
  - `05-semantic-path` — for hover scores and reranking value
  - `04-language-modules` — for the language detection path
- **Cross-repo:** new repo `kotoshu/kotoshu-lsp`; depends on
  `kotoshu/dictionaries` and (optionally) `kotoshu/models-fasttext-onnx`
  at runtime via the cache layer.
- **Promotes from:** T6.1 in `56-t4-t5-t6-quality-architecture-ecosystem.md`

## Out of scope

- A VS Code extension (that's `61-editor-ecosystem.md` — the extension
  just bundles the LSP server; it doesn't reimplement it).
- Grammar diagnostics beyond what `Kotoshu::Grammar` already produces.
  Grammar rule packs land via `08-grammar-engine` /
  `51-grammar-engine-expansion`.
- Multi-file workspace-wide analysis (defer to a future
  `workspace/diagnostic` refresh pull).
- Translation of suggestion text to the user's UI locale — suggestions
  are dictionary-language-scoped by design.

## Risks

- **Ruby startup latency.** `ruby` cold start is ~100–200 ms, fine for a
  long-running LSP server but worth a baseline benchmark. If startup is
  a problem, evaluate `ruby --enable-frozen-string-literal` and
  `bootsnap`.
- **Single-threaded model.** MRI's GIL means long `Kotoshu.check` calls
  block JSON-RPC reads. Run heavy analysis on a worker thread; the
  server thread only handles protocol I/O.
- **Editor coverage.** Each editor has quirks (JetBrains' LSP connector
  lags Neovim's). Document per-editor caveats in the gem README; don't
  let one editor's bug block the release.

## Status

_Pending._ New repo `kotoshu/kotoshu-lsp` to be created as the first
task. Phase 1 + Phase 2 (steps 1–9) is a coherent v0.1 release; phases
3–4 are v0.2.
