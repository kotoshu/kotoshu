# 10 — Testing & CI

## Goal

A test suite that meaningfully verifies behavior (not just that methods
are called) and a CI pipeline that prevents regressions across the
supported Ruby version and language matrix.

## Why

Current state:
- `:network` specs are gated behind `NETWORK_TESTS=1`, meaning default
  `bundle exec rspec` skips large chunks of behavior
- No CI workflow visible in the repo for the gem itself
- SimpleCov is configured but `minimum_coverage` is commented out
  (`# TODO: Re-enable when coverage increases`)
- No performance regression gates
- Many root-level `test_*.rb` files bypass RSpec entirely

## Tasks

1. **CI workflow.** Add `.github/workflows/ci.yml`:
   - Matrix: Ruby 3.1, 3.2, 3.3
   - Job 1: `bundle exec rake` (default = spec + rubocop)
   - Job 2 (nightly, separate): `NETWORK_TESTS=1 bundle exec rspec` —
     uses cached resources to avoid re-downloading
   - Job 3: `bundle exec rspec spec/performance/` — runs benchmarks,
     fails on >20% regression vs. baseline committed in
     `spec/performance/baseline.json`
2. **Coverage gate.** Re-enable `minimum_coverage` once it's at a
   meaningful number. Target: 80% line coverage of `lib/` excluding
   `lib/kotoshu/cli/` (interactive UI is hard to test).
3. **Spec hygiene.**
   - No `double()` anywhere (project rule). Audit and replace with real
     instances or `Struct`.
   - No VCR / mocks of HTTP (commit `90aa886` already removed these;
     ensure they don't come back). Network specs use a Sinatra fake
     server fixture.
   - Every spec under `spec/kotoshu/` mirrors `lib/kotoshu/` 1:1.
4. **Property-based tests.** Expand `spec/properties/`:
   - Tokenizer round-trip: every word a tokenizer extracts can be
     re-inserted at its offset to reconstruct the original
   - Suggestion idempotency: a correct word never appears in
     suggestions for itself
   - Hunspell fixture port: every Spylls test scenario is covered
5. **Integration test matrix.** A single
   `spec/integration/matrix_spec.rb` iterates each supported language
   and runs 5 sample documents through the full pipeline (tokenize →
   resolve → analyze → suggest → format). Tags: `:network` (downloads),
   `:slow` (>5s). Lets us see at a glance which languages are healthy.
6. **SARIF validation.** Spec that runs `check` and feeds the SARIF
   output through the official SARIF validator gem; fail CI if invalid.
7. **Move root scratch files.** `test_affix*.rb`, `test_onnx_*.rb`,
   `test_vocab_setup.rb`, `test_combined_cache.rb`, `verify_onnx_all.rb`,
   `deploy_onnx_all_languages.rb`, `monitor_onnx_progress.sh` — move
   useful ones into `scripts/`, delete pure scratch (ask first per
   global rule).
8. **Conformance harness.** A script that runs Kotoshu against the
   Hunspell reference test corpus and reports pass rate. Becomes the
   source of truth for plan `01-hunspell-correctness` status.
9. **Flake detection.** CI runs the full suite 3 times; any example
   that fails non-deterministically is flagged.

## Acceptance criteria

- PRs to `main` cannot merge if `bundle exec rake` fails
- Coverage report shows ≥ 80% on `lib/` (excluding CLI)
- `NETWORK_TESTS=1` job runs nightly, posts a summary of
  language-matrix results to the repo's Actions tab
- No `double()` calls in the codebase (`grep -rn 'double(' spec/` is
  empty)
- No `test_*.rb` files in the repo root

## Dependencies

- None — can run in parallel with everything else
- Unlocks: confidence for `11-release`

## Out of scope

- Fuzzing (out of scope for v1)
- Mutation testing (`mutant` gem) — stretch goal
- Stress/load testing of a future HTTP server

## Status

_Pending._

## Source

`docs/TDD_ITERATION_STRATEGY.md` (original dated 2025-01-29) is the
methodology reference: TDD + MDD cycle, walking skeleton, 10-week
build-out, Definition of Done per vertical slice. The build-out is
substantially executed (walking skeleton, core models, all dictionary
backends, suggestion strategies, Hunspell port all exist with specs).
Load-bearing rules from that doc — no doubles, test-behavior-not-
implementation, Strangler Fig for large refactors — live in
`~/.claude/CLAUDE.md` and `CLAUDE.md`, not duplicated here.
