# 11 — Benchmark and the SOTA comparison matrix

## Test data

| corpus | languages | sentences | error types | public |
|--------|-----------|-----------|-------------|--------|
| BEA-2019 | en | ~4,477 (test) | all W&I+LOCNESS | ✅ |
| CoNLL-2014 | en | 1,312 (test) | NUCLE | ✅ |
| FCE | en | ~28k | Cambridge Learner Corpus | ✅ |
| RL CASOC | de | ~5k | German learner corpus | ✅ |
| LANG-8 | multi | ~1M | mixed (noisy) | ⚠️ |

Primary: BEA-2019 (the standard GEC benchmark).
Secondary: CoNLL-2014 (the classic, for comparability with literature).

## Metrics

- **Precision**: of flagged errors, how many are real errors
- **Recall**: of real errors, how many are flagged
- **F0.5**: the standard GEC metric (weights precision 2× recall)
- **Per-rule FP rate**: rules must stay under budget (≤2%)

## Baseline: LanguageTool CLI

Run LT CLI on the same test sentences with default settings (all
rules enabled, no ML). Record their P/R/F0.5 for comparison.

## The published matrix

| solution | en rules | P | R | F0.5 | languages | client-side | unique capabilities |
|---|---|---|---|---|---|---|---|
| kotoshu (rules) | 150 | measured | measured | measured | 16 | ✅ | cross-script, realword, variant-pure |
| kotoshu (rules + stats) | 150 + stat | measured | measured | measured | 16 | ✅ | collocation anomaly |
| kotoshu (rules + stats + neural) | 150 + stat + GECToR | measured | measured | measured | 16 | ✅ | full hybrid |
| LanguageTool | 2,700 | measured | measured | measured | 30+ | ✅ | — |
| GECToR (literature) | learned | ~78 | ~40 | ~65 | en | ❌ | — |
| T5-11B (literature) | learned | ~82 | ~55 | ~75 | en | ❌ | — |

## What "SOTA" means here

We are SOTA when:
1. F0.5 ≥ LanguageTool on the same test set (parity)
2. We have unique capabilities LT doesn't (cross-script, realword,
   variant-pure zh, statistical grammar)
3. All results are client-side (no API calls)
4. All numbers trace to committed frozen reports
