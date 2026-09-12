# Plan 128 — The hybrid ship decision: price C-retrieve + fastText-rescore on the closed data blocker

Status: executed — VERDICT SHIP=True (models PR #34, 2026-09-12)

The full arc: frozen cbench rebuilt byte-faithfully (every sha256
reproduced; only the receipt wall-clock differed, reverted), c_typo_v2
retrained (0.481 MB, probe_hit5 0.410), pricing verdict per the
pre-declared rule: hybrid beats full on top-1 AND top-5 in all four
REAL components (en +6.3pp top5 CI [+4.9,+7.7] decisive; de +28.6,
ru +11.1, es +10.0), degrades nowhere, 25.8 MB int8 at ~3-4 ms.
Densified: on ~4,700 synth pairs/lang the hybrid evaluates essentially
all (top5 0.467-0.478) where full embeds only 69-85 pairs. Engine
productization = the follow-on plan (131).
Depends on: plan 123 (corpora shipped; the data blocker that parked
plan 115), plan 114 (the frozen C-benchmark + pre-declared verdict rule)

## Problem

Plan 115 priced the hybrid retrieval thread and parked on missing de/es
typo data. Plan 123 closed that blocker (5,000 dictionary-grounded
pairs each). The plan-114 artifacts (frozen cbench files, c_typo_v2
encoder) were gitignored and wiped in the September cleanup — but the
corpus is vendored, the builder and trainer are committed, and the
whole chain is deterministic. The verdict arc is executable end to end.

## Execution

1. Rebuild the frozen C-benchmark: `scripts/build_cbench.py` — the
   receipt (eval/reports/cbench.frozen.json) carries per-file sha256s;
   the rebuild must reproduce them byte for byte or the freeze is
   broken and the run stops (integrity before evidence).
2. Retrain `c_typo_v2`: `scripts/train_typo_biencoder_v2.py` (char
   bi-GRU, CPU, minutes; artifacts gitignored as before).
3. Price: `eval/hybrid_pricing_bench.py` over en/de/ru/es — the frozen
   REAL components are the ship gate (unchanged), the plan-123 corpora
   are additional labeled evidence for the de/es gap.
4. Verdict per the plan-114 pre-declared rule (wins on real, degrades
   nowhere with n>=20) — ship, or reject on data like 114 did. Either
   outcome closes the thread honestly.

## Acceptance

- The cbench rebuild reproduces every frozen sha256.
- The pricing report lands (eval/reports/hybrid-pricing.json refresh)
  with real + synth components labeled, and the verdict is recorded in
  the plan status with numbers.
- No frozen artifact changes; new evidence only.
