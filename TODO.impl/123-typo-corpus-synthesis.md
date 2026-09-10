# Plan 123 — Verifiable typo corpora, synthesized at scale

Status: designed (execution-ready; next session — models-repo arc)
Depends on: plan 115 (hybrid pricing blocked on real de/es corpora);
validated direction: DeepSeek-V4.1-Flash §5.1 — data/environment
synthesis exceeds algorithmic novelty

## Problem

Plan 114's surviving thread (C-retrieve + fastText-rescore hybrid)
beat the full tier on all four real components but was parked for lack
of real de/es typo corpora; plan 115 priced the thread and named the
corpus as the blocker. Meanwhile the eval harness already owns the
generators: `eval/noise.py` (keyboard-aware grids, Turkish-Q/JCUKEN/
Greek, parameterized Latin family) and the per-language dictionaries.

## Design

- Formalize a corpus entry as (typo, correction, provenance) — the
  verification system is the dictionary itself plus the noise model:
  a pair is admitted iff the correction is dictionary-valid, the typo
  is not, and the typo is reachable from the correction by the
  declared noise operation(s). Difficulty calibration = the noise
  op mix and edit distance distribution, reported per corpus.
- Scale: ≥ 5k pairs per language for de and es (matching the en
  frozen benchmark's 2,509 real pairs at minimum, target 2x), plus
  pt/fr as stretch; dedup by (typo, correction); stratify by distance
  1/2 and by keyboard-adjacency vs random substitution.
- Honest split: synthesis trains/reprices, it must NOT be presented
  as "real user" data — corpora carry `synthetic: true` provenance
  and the plan-115 pricing reruns on both the frozen real components
  (unchanged) and the synthetic corpora (new).
- Gates: the hybrid must still win on real components; synthetic
  corpora may only ADD evidence, never replace the real gates
  (pre-declared rule, plan 114 discipline).

## Acceptance

- de/es corpora checked in with provenance + difficulty histograms.
- Plan 115 pricing rerun: hybrid vs full tier on real (unchanged) +
  synthetic (new) — ship-only-if-wins applies to the union.
