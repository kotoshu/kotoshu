# Plan 138: ext pin drift guard + typo-retrieval docs

## Status: executed

## Problem

1. **Silent pin drift.** The ext tracks kotoshu-rs main via a git rev in
   the root `Cargo.lock`. Every rs merge moves main ahead while the pin
   stays — and nothing fails: `rake compile` happily builds the old
   extension, and the typo layer's degrade rescue swallows the missing
   surface. Today that cost a live incident: a stale local ext lacked
   `TypoEngine.matrix`, `Engine.for` silently fell back to deriving, and
   arming took **31.8 s instead of 588 ms**. Drift is invisible exactly
   when it matters.
2. **Undocumented feature.** `kotoshu setup LANG --typo` and
   `KOTOSHU_TYPO_RETRIEVAL` shipped in 1.0.3 with no README section —
   the flag is the only entry point and nobody can find it.

## Changes

- `Rakefile`: `pinned_rs_rev` helper shared by `ext:update` (one
  extraction, two consumers — the extraction can never diverge) and a
  new `rake ext:pin_check` that compares the pin against
  `KOTOSHU_RS_HEAD` and aborts with the `ext:update`-plus-PR recipe on
  drift (network stays at the workflow boundary).
- `.github/workflows/ext-pin-drift.yml`: weekly Monday 04:00 UTC +
  `workflow_dispatch`; fetches rs main HEAD via `gh api` and runs the
  check. Failing scheduled runs email the repo owner.
- `spec/kotoshu/rake_ext_update_spec.rb`: three pin_check specs running
  the REAL task in a real subprocess against the REAL Cargo.lock
  (match passes; behind fails with recipe + pinned sha; absent
  KOTOSHU_RS_HEAD fails honestly).
- `README.adoc`: `[[typo-retrieval]]` section — what the layer does,
  the measured recall lifts, the `--typo` setup flag, the
  `KOTOSHU_TYPO_RETRIEVAL` opt-in, the byte-identical passthrough when
  off, and the prebuilt-matrix arming story.

## Evidence (2026-09-14)

- `bundle exec rspec spec/kotoshu/rake_ext_update_spec.rb` — 5
  examples, 0 failures.
- Live: `rake ext:pin_check KOTOSHU_RS_HEAD=$(gh api …/commits/main
  --jq .sha)` → `kotoshu-rs pinned at main (0001b50056)`.
