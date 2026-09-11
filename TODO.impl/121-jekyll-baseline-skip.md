# Plan 121 — Jekyll generator skips the sweep for baseline-covered words

Status: executed (gem PR #181, 2026-09-11)

Third call site wired: the generator builds the per-file budget from
its own baseline store and threads suggestions_filter through
Kotoshu.check. Generator spec proves a beyond-budget occurrence
surfaces with suggestions while covered words never pay for the
sweep.
Depends on: plan 116 (the suggestions_filter mechanism)

## Problem

The rake task and the CLI thread `suggestions_filter:` through their
check callables; the Jekyll generator (plan 89) has its own baseline
store (`lib/kotoshu/jekyll.rb`) but still calls the checker without
the filter — Jekyll builds pay the full suggestion sweep for entries
their baseline then suppresses. Same repository, same mechanism,
three call sites, two wired.

## Fix

- Build the per-file budget filter via `store.suggestions_filter_for`
  exactly as `Cli::DirectoryCheck` does, pass it through the check
  call. The generator's baseline is a `Baseline::Store` already — the
  filter comes from the same object (DRY by construction).
- Spec: a Jekyll site fixture with a baseline; assert suppressed
  entries carry no suggestions and a new error does.

## Acceptance

- Generator output unchanged; sweep cost on baselined sites drops as
  it did for the rake task (plan 116 evidence).
