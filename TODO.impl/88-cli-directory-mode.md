# 88 — CLI directory mode: check a whole tree

## Context

`kotoshu check` handles one file or stdin. Every serious checker
(cspell, codespell, hunspell wrappers) checks a directory tree — that
is the actual CI workflow (`action-kotoshu` users fake it with
find/xargs today). Baselines (gem PR #118) already key on file paths,
so directory mode + baselines is the complete CI story.

## Design

- `kotoshu check DIR [DIR...]` — walk the tree; check files whose
  extension is a known text format (markdown, asciidoc, txt, rst,
  adoc, mdx) unless `--include`/`--exclude` globs say otherwise.
- Respect `.gitignore` (and `.ignore`) semantics: implement the
  standard glob subset (directories, `*`, `**`, `?`, negation `!`,
  trailing `/`); document the subset honestly. NO shelling out to
  git — the vision forbids external binaries.
- Hidden files/dirs and `node_modules`/`.git`/`vendor`/`target`
  skipped by default.
- Output: per-file sections in text mode; one combined SARIF/JSON
  document with per-file runs. `--baseline` applies per file+word as
  shipped. Exit codes unchanged (1 = errors found).
- Interactive mode stays file-only (documented no-op with a message
  for directories).

## Specs

Real directory trees in specs (tmpdirs with fixtures + .gitignore
cases: negation, nested ignores, globstar). Behavior specs, no
doubles.

## Status

**Pending.**
