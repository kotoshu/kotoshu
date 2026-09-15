# Plan 142: arm-time matrix↔tier pairing verification

## Status: executed

## Problem

A KTM1 matrix's rows are index-parallel to EXACTLY the full-tier
vocabulary they were derived over. Nothing on the gem side knew the
pairing: a rebuilt full tier (new vocab order) behind a stale cached
matrix armed silently-wrong slates — every row retrieving a different
word than it was quantized for.

## Changes

- `ModelRegistry::Resource` gains `paired_vocab_sha256` (models plan
  14 ships it in the registry; nil on older registries and non-matrix
  resources — the lutaml model previously tolerated the unknown field,
  now it reads it).
- `download_typo_matrix` records `paired_tier_sha256` in the matrix
  cache metadata from the entry.
- `load_cached_typo_matrix(language, paired_tier_sha256:)` answers nil
  when the caller states a tier the cached matrix does not pair with.
  Matrices cached before the field existed carry no record and stay
  loadable (backward compatible).
- `Engine.for` states the cached tier's checksum
  (`tier[:metadata]["checksum"]`), so a stale pairing falls back to
  deriving — safely slow instead of silently wrong. The rs
  `from_matrix` count guard (rs PR #45) is the structural backstop
  beneath this.

## Evidence (live, 2026-09-15)

- Registry re-fetch + matrix re-download on the shipped field:
  metadata `paired_tier_sha256` = `cf826747600a…` == the cached tier
  checksum; `Engine.for("en").armed_via` = `:matrix`.
- Cache boundary: matching pairing loads; a stated foreign tier sha
  is rejected (nil).
- `rspec cache/model_cache_typo_spec resource_manager_typo_spec
  typo/engine_for_spec` — 36 examples, 0 failures (2 pending E2E);
  rubocop clean.

## Sister work

- models plan 14 (#46, merged): the registry carries and enforces the
  pairing (`paired_vocab_sha256`, cross-checked against the manifest).
- rs #45: `from_matrix` rejects a row-count/vocab-length mismatch.
