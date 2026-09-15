# Plan 144: RBS truth, examples sweep, catalog branch fix

## Status: executed

## Problem

1. **The RBS signature file was never valid.** `sig/kotoshu.rbs` had
   pre-existing syntax errors (`?options ::Hash` double-colons, an
   invalid `Struct[...]` superclass) — it could not parse, so no type
   checker could ever consume it — and it knew nothing of the
   plan-131–143 public surface.
2. **Four of fifteen numbered examples were broken** —
   documentation-as-code lying about the library.
3. **`Dictionaries::Catalog` fetched from a dead branch** — a REAL
   user-facing bug: every catalog `dic_url` pointed at
   `dictionaries/main`, but that repository lives on `v1` (all URLs
   404).

## Changes

- RBS: fixed the syntax errors (the file now parses for the first
  time) and declared the missing surface — `InputFileNotFoundError`,
  `Spellchecker#check_file`/`#check_directory`, `Typo::Engine`
  (`.for`, `.setup_typo`, `armed_via`, `#suggest`), `ResourceManager`
  (`setup?` incl. `:typo_matrix`, `languages_setup`, `setup`,
  `resolve`), `ModelCache`'s typo-matrix pair
  (`load_cached_typo_matrix` with `paired_tier_sha256`,
  `download_typo_matrix`, biencoder pair).
- Examples: 12/13/14 now `require "kotoshu"` (the facade) instead of
  loading internals out of order; 14 uses the real protocol API
  (`VocabularyProtocol.compliance_errors`, not the never-existing
  `Protocols::` namespace); 12 uses `language_info` (the current
  name).
- Catalog `BASE_URL`: `main` → `v1`.

## Evidence

- `RBS::Parser.parse_signature` — PARSES OK (original failed at three
  sites).
- All fifteen `examples/[0-9]*.rb` exit 0.
- Catalog spec 16/0; rubocop clean after autocorrect.

## Sweep residue

Per-language demo scripts (`de_german_example.rb` etc.) and the
benchmark scripts were not part of this pass — the numbered
walkthroughs (the documented path) are the sweep's contract.
