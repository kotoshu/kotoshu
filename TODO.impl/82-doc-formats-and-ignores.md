# 82 — Document ignores + CI baselines

## Context

Two long-standing user gaps in the gem (verified 2026-09-05 — no
`disable` handling exists anywhere in `lib/kotoshu/documents/`):

1. **Inline ignores** — a word that is intentionally "wrong"
   (product names, code identifiers in prose, dialect) cannot be
   suppressed per-line; users fall back to polluting the personal
   dictionary.
2. **CI baselines** — `kotoshu check` in CI fails on ALL known
   errors forever; there is no way to freeze existing debt and fail
   only on new errors. Every serious linter has this (ESLint
   `--baseline`, RuboCop `--exclude-limit` culture, cspell
   `--no-cache` + wordlists).

## Track A — ignore directives

Syntax (comments recognized by each document format's parser):

```
kotoshu:disable-line                 — suppress everything on this line
kotoshu:disable-next-line            — suppress on the following line
kotoshu:disable-next-line foo bar    — suppress only these words
kotoshu:disable-file / kotoshu:enable-file  — block suppression
```

- Markdown: HTML comments `<!-- kotoshu:disable-next-line -->`;
  AsciiDoc: `// kotoshu:disable-next-line`; plain text: a line whose
  trimmed content is the directive. Trailing directives
  (`text <!-- kotoshu:disable-line -->`) supported in MD/ADOC.
- Implementation: document layer (`documents/`) attaches
  `suppressions` (source ranges) during parse; the checker filters
  results whose range/word matches. Suppression data flows through
  the public result objects (`results/*`) so SARIF/JSON consumers
  see suppressed entries either omitted or marked (omitted by
  default; `--show-suppressed` lists them).
- Also recognized: the spellchecker facade (`.check`) so the gem
  API gets it for free.

## Track B — baseline files

- `kotoshu check --baseline .kotoshu-baseline.json`:
  - Baseline format: canonical JSON `{file, line, word, count}` —
    stable across reformatting (count-based, not position-based).
  - `kotoshu baseline init` generates it from current findings.
  - Semantics: an error passes if it matches the baseline
    (same file+word, count not exceeded); new errors fail; a
    summary line reports how many baseline entries are now stale
    (file no longer has the error) so debt shrinks visibly.
  - SARIF output marks suppressed entries with the baseline tag.

## Specs

Behavior specs throughout (no doubles; real documents). Cover:
directive forms per format, word-scoped suppression, block
disable/enable nesting, baseline count semantics, stale-entry
reporting, SARIF marking.

## Phases

A1 directive parsing + filtering → A2 per-format specs + docs page
section → B1 baseline format + commands → B2 CI docs example.

## Owner gates

None. CHANGELOG entry under Unreleased (version = owner).

## Status

**Pending.**
