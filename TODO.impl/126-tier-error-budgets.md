# Plan 126 — Publish the measured error budget per tier

Status: executed (site 70df393, 2026-09-12)

/performance carries the table: 55-language worst-case rank_corr /
top-1 agreement per tier against the gates, the vocabulary-cut
caveat, and the plan-123 finding that even the full tier embeds only
~1.5% of dictionary-grounded typos.
Depends on: the 2026-09-10 model-efficiency research (DeepSeek-V4.1-Flash:
every "cheaper" claim carries its measured number)

## Problem

The site documents tier sizes and the near-lossless headline
(fluency rank_corr 0.9999) but not a per-tier, per-language error
budget a user can reason about: what quality do I trade for mini's
3 MB vs fluency's 15 MB vs full? The numbers exist (gates.json,
corpus benches); they are just not published as a table.

## Fix

- /docs/performance gains an "Error budget" section: per tier, the
  frozen gate values (fluency rank_corr, top-1/top-5 agreement deltas
  vs full on the real corpora) with corpus sizes stated, plus the
  dictionary-only baseline for contrast.
- The table cites its source (eval gates at registry tag) and its
  date; numbers regenerate with each registry release (script optional
  — a hand-truthed table with provenance beats a stale pipeline).

## Acceptance

- A user can answer "what do I lose on mini?" with one number pair.
- The section states corpora sizes and OOV caveats honestly.
