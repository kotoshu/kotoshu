# Plan 139: typo observability — armed_via + setup --list detail

## Status: executed

## Problem

1. **Silent arming path.** `Engine.for` preferred the matrix when
   present and derived otherwise, but nothing recorded which path won.
   A stale ext missing `TypoEngine.matrix` (the plan-138 incident)
   looked identical to a successful matrix arm from the outside —
   31.8 s of deriving with no signal. `defined?(…matrix)` was also the
   wrong existence check (use `respond_to?`).
2. **Opaque setup list.** `kotoshu setup --list` printed language codes
   only. An install with the pair+tier but no matrix (derives at arming)
   looked the same as one with the matrix (instant arming).

## Changes

- `Typo::Engine#armed_via` → `:matrix` | `:derived`. Set at construction
  so the E2E / live path can assert which arm won. `respond_to?(:matrix)`
  replaces `defined?(…matrix)`.
- `ResourceManager.setup?(lang, resource: :typo_matrix)` — sha-verified
  matrix presence (same contract as `load_cached_typo_matrix`).
- `kotoshu setup --list` prints per-resource detail:
  `en: spelling, model, typo, typo-matrix`.

## Specs

- `resource_manager_typo_spec`: setup? :typo_matrix false/true.
- `engine_for_spec`: armed path asserts `armed_via == :derived` without
  a matrix; new matrix path (gated on `KOTOSHU_TYPO_E2E` +
  `KOTOSHU_TYPO_MATRIX`) asserts `:matrix`.
- `cli/end_to_end_spec`: setup --list matches `/en:.*spelling/`.

## Evidence

- Live: `Engine.for("en").armed_via` → `:matrix`; `Engine.for` with
  matrix moved aside → `:derived`.
- `kotoshu setup --list` after the plan-12 de setup →
  `de: spelling, model, typo, typo-matrix`.
