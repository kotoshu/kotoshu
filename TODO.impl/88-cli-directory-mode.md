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

**Implemented 2026-09-05 (gem PR feat/cli-directory-mode).**
`kotoshu check FILE [DIR ...]`: DirectoryWalker selects known text
extensions by default (md markdown asciidoc adoc txt rst mdx) with
--include/--exclude globs replacing/overriding the default
(slashless globs match basenames, slashed globs match the path from
the root); hidden entries and .git/node_modules/vendor/target are
always skipped. IgnoreMatcher implements the .gitignore/.ignore
glob subset in Ruby (no shelling out): * ? ** anchoring trailing-/
directory patterns ! negation with last-match-wins, nested
scoping, and git-style no-re-include under ignored directories.
Output: per-file text sections + summary; one combined JSON
document (fileCount/wordCount/errorCount/files[] with the
single-file payload keys); one SARIF run per file. --baseline
applies per file unchanged; exit codes unchanged; interactive mode
prints a file-only notice for directory targets. Single-file and
stdin paths are byte-identical (the single-file code path is
preserved verbatim). Behavior specs run the real CLI against real
tmpdir trees with the real en dictionary from committed fixtures -
no network, no doubles.
