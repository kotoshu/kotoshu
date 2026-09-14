# Plan 140: reader-side TTL freedom, flake fix, matrix-arm CI

## Status: executed

## Problem

1. **Three-way disagreement on expired-but-present caches.** The live
   machine carried an `ar` spelling cache whose metadata predates
   `cached_at` bookkeeping. `languages_setup` listed it, `cached_data?`
   and `load_cached` accepted it, but `resolve`/`setup?` guarded on the
   TTL-enforced `available?` — so `Kotoshu.correct?` raised
   `ResourceNotSetupError` for a language `setup --list` claimed was
   ready, and `setup --list` printed an empty `ar:` row (plan 139's
   fallback hid the symptom). Plan 117 already settled the principle:
   present checksummed bytes ARE the dataset; expiry is a refresh
   signal for setup, never absence for readers. The resolve path never
   caught up.
2. **Recurring CI flake.** `spec/properties/property_based_spec.rb`'s
   parallel-checker example kept only `Tempfile#path` strings; the
   Tempfile objects were GC-finalizable mid-example and unlinked the
   files under the sequential phase (manifesting as
   `DictionaryNotFoundError` on the input file — `check_file` raises
   that class for any missing path). Cost a rerun on PR #206.
3. **The matrix arm had no CI coverage.** The `armed_via=:matrix`
   spec skips without `KOTOSHU_TYPO_E2E`/`KOTOSHU_TYPO_MATRIX`; only
   the release-time surface guard covered the shipped gem. The 1.0.4
   class of break (ext lacking the typo surface) passed every PR gate.

## Changes

- `resolve_spelling_cached`, `resolve_frequency_cached`,
  `resolve_tier_cached`, `resolve_model_cached`, and every `setup?`
  branch: `available?` → `cached_data?`. The setup flows keep
  `available?` (expiry → refresh there); the contracts are now MECE —
  `available?` answers "fresh enough to skip setup", `cached_data?`
  answers "usable bytes on disk".
- The property spec holds the Tempfile objects for the example's
  lifetime (`tempfiles` let + `unlink` in `after`).
- `conformance.yml` native-suite runs `kotoshu setup en --typo` and
  exports the artifact paths, so both armed specs run on every PR:
  derived asserts `:derived`, matrix asserts `:matrix`.

## Evidence (2026-09-14, live machine)

- `ar`: `setup?` false→**true**, `resolve` raises→**returns
  Dictionary::Hunspell**, `setup --list` `ar:`→`ar: spelling`.
- `rspec resource_manager* bundle specs` — 65 examples, 0 failures;
  the parallel property — 6 consecutive green runs.
- rubocop clean.

## Observed, not changed

`Spellchecker#check_file` raises `DictionaryNotFoundError` for a
missing *input* file — semantically wrong class, but public behavior;
left for an owner-scoped pass.
