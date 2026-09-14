# Plan 137: typo-matrix backfill on satisfied setups

## Status: executed

## Problem

Two gaps left plan 136's instant arming unreachable through the CLI:

1. **LFS (models repo, fixed by PR #40):** the KTM1 matrix landed as a
   plain git blob — `.gitattributes` had no `*.ktm1` rule — so the
   registry's media-host mirror URL 404'd and `kotoshu setup en --typo`
   could not download the matrix. The raw host served it; the media host
   (LFS-only) did not.
2. **Backfill (this repo):** `ResourceManager#setup_typo_remote` returned
   `:cached` early when the typo pair + full tier were cached, never
   touching the matrix — and its download path didn't fetch the matrix
   either. Only the library API (`Kotoshu::Typo::Engine.setup_typo`) did.
   An install set up before the matrix existed (or a fresh one, before
   this fix) would derive at arming time (~25-30s) forever.

## Changes

- `setup_typo_remote`: both paths now call `ensure_typo_matrix(cache, lang)`
  — cache-only stat via `load_cached_typo_matrix`; best-effort fetch
  otherwise (`:downloaded` on success, `nil` → degrade to `:cached` on
  absent entry or network failure — the fallback remains deriving).
- Specs (`resource_manager_typo_spec.rb`): backfill-on-satisfied-setup
  against a real local HTTP server; stays-`:cached` when the matrix is
  already cached; degrades-`:cached` with no registry entry.

## Sister work

- models PR #40 (merged): `*.ktm1` LFS rule + renormalization — content
  sha unchanged, registry untouched.
- models plan 10 / PR #41: `validate_registry.py --check-urls` fetchability
  gate in CI and the release flow, so a dead mirror can never land again.

## Evidence (live, 2026-09-14)

- Mirror: `media.githubusercontent.com/.../typo.matrix.en.ktm1` → 200,
  KTM1 magic, 26000016 bytes.
- `kotoshu setup en --typo` (registry wiped, pair+tier cached):
  `typo: downloaded`, matrix cached, 2.1s.
- Arming: 31.8s (derive, stale-ext baseline) → **588ms** via
  `TypoEngine.matrix` (after `rake ext:update` — the binding ships in
  kotoshu-rs 0.2.0).
- `engine.suggest("recieve")` → `["recieved", "recieving", "receive"]`
  in 9ms.
- `bundle exec rspec spec/kotoshu/resource_manager_typo_spec.rb
  spec/kotoshu/cache/model_cache_typo_spec.rb` → 25 examples, 0 failures.
