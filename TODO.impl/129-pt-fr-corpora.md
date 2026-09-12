# Plan 129 — pt/fr synthetic corpora (plan 123 stretch targets)

Status: executed (models PR #34, 2026-09-12) — 5,000 pairs each,
same rule, tests at four languages; tier numbers in the refreshed
synth-corpus summary.
Depends on: plan 123 (the generator)

## Problem

Plan 123 shipped de/es; pt and fr were declared stretch targets. The
generator, tests, and bench all generalize by construction — extending
is a parameter, not new code.

## Fix

- Generate eval/corpora/synth/{pt,fr}.json at the same 5,000-pair
  target with the same admission rule (pt: ABNT qwerty + accents; fr:
  azerty alternates — both already in noise.py's layout registry).
- Extend the tier baseline bench + tests to the new languages.

## Acceptance

- Same invariants as 123, same test coverage, tier numbers recorded.
