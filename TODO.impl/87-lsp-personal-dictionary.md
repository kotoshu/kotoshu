# 87 — kotoshu-lsp: read the personal dictionary

## Context

The VS Code extension's "add to personal dictionary" writes
`~/.config/kotoshu/personal.dic` (same path + format as the gem CLI —
`Kotoshu::Paths.personal_dictionary_path`), but the LSP server never
READS it. The user adds a word, the diagnostic stays, the feature
feels broken. Found by the vscode agent (wave 1) and confirmed by
grep: server.rb only *writes* suggestions for the action.

## Design

- On server start AND on dictionary-file change, load the personal
  dictionary (gem API: `Kotoshu::PersonalDictionary` — reuse, do not
  re-parse) into the spellcheck path so its words are correct.
- File watching: simplest honest approach that works everywhere —
  mtime check on didOpen/didChange re-checks (cheap stat), plus a
  documented limitation note in README (no OS file watcher needed
  for v0.1.x).
- After an add-to-dictionary code action (server executes the write
  itself, or the client notifies via workspace/didChangeConfiguration
  / custom notification), re-publish diagnostics for open documents.
  Prefer: the SERVER performs the write (single writer, no
  client/server filename drift) — the extension's client-side write
  moves to the server command; keep the extension working with both
  (it may still write for its own UI; server write wins when present).
- Specs: real temp personal.dic files (no doubles); add → diagnostic
  clears; KOTOSHU_PERSONAL_DIC env honored (gem Paths already does).

Leaves the repo 0.1.1-ready (owner dispatches the release; RubyGems
0.1.0 is empty — see the wave-1 fixes).

## Status

**Pending.**
