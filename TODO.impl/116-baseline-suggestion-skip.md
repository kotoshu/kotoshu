# Plan 116 — Baseline-aware suggestion skip in `kotoshu check`

Status: executed (gem PR #175, 2026-09-10)

Measured on this repo's own dogfood gate (prose baseline, 640 entries /
1,905 covered occurrences): check wall time 13m+ -> 13.7s, identical
output. Full default suite 4003/0.
Depends on: plan 82 (baselines), plan 113 (packs — unrelated but same file surfaces)
Blocks: nothing; targets the 0.11.x line before 1.0

## Problem

`kotoshu check --baseline` in CI regenerates the suggestion sweep for
every error it is about to suppress. On the kotoshu repo itself the
prose baseline holds 1,905 occurrences across 7 files; the check phase
of the dogfood gate spends ~10 CPU-minutes producing suggestions that
the baseline then throws away. The site repo's spellcheck job runs
6m48s for the same reason. Suggestions only matter for errors that
SURVIVE the baseline — those are the rows a human reads.

`kotoshu baseline init` already fixed this for itself
(`Spellchecker#check(text, suggestions: false)`, plan-executed in
"fix(cli): make baseline init usable on real repositories"). `check`
still pays full price.

## Design

The budget is knowable before checking: the baseline entry list for the
file under check says exactly which words will be absorbed (and how
many times). So:

1. `Cli::DirectoryCheck` (and the single-file check path) computes
   `covered = baseline.entries_for(path)` → a word→count budget hash,
   before invoking the spellcheck callback.
2. `Spellchecker#check` gains an optional `suggestions_filter:` hook —
   a callable receiving the word, returning whether to generate
   suggestions. Default nil = generate for everything (current
   behavior). The loop already has the `suggestions:` branch; this
   generalizes it without touching result shape.
   - Occurrence counting must be honored: the budget for `wrold: 3`
     means the first 3 occurrences skip, the 4th (a NEW error)
     generates. The filter therefore closes over a mutable budget
     hash in the caller, decremented per consumed occurrence.
3. Errors suppressed by the baseline keep their (empty) suggestion set
   — unchanged from today, since suppressed rows render without
   suggestions anyway.
4. New errors — beyond budget or unknown words — generate suggestions
   exactly as today. SARIF, text, and JSON output shapes unchanged.
5. Inline-suppressed words: keep generating suggestions today (they
   are dropped at assembly regardless) — fold into the same skip by
   treating `kotoshu:disable` regions as covered when the suppression
   scan already knows the word/line. Out of scope if the scan order
   makes this awkward; the baseline case is the measured cost.

## Surfaces touched

- `lib/kotoshu/spellchecker.rb` — `check(text, suggestions:,
  suggestions_filter:)`
- `lib/kotoshu/cli/directory_check.rb` — budget construction from the
  loaded baseline, filter closure
- `lib/kotoshu/cli.rb` — single-file `--baseline` path, same wiring
- `spec/kotoshu/cli/baseline_cli_spec.rb` — new cases: covered word
  beyond budget generates suggestions; covered occurrence does not;
  no baseline = unchanged

## Non-goals

- No output format changes; suppressed rows stay suggestion-less.
- No change to `Baseline::Store` semantics (apply stays the authority
  on pass/fail); the filter is purely a compute optimization whose
  visible effect is empty suggestions on rows that were going to be
  suppressed.

## Acceptance

- Dogfood gate on the kotoshu repo: check phase wall time drops from
  ~10 min to under ~2 min (the sweep itself, minus 1,905 suggestion
  generations).
- All existing baseline specs green; new filter specs green.
- Site repo spellcheck job measurably faster after its gem bump.
