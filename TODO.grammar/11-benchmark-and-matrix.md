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

## Measured state (2026-11-11)

The plan above is superseded by the measured campaign below. Every
number here comes from the frozen measurement pipeline (decodes run on
the shipped artifact, official M² scorer for CoNLL-14, strict span
scorer with artifact guards elsewhere; frozen reports per cell).

### Published models (all fully local ONNX, no API at serve time)

| model | benchmark | score | comparison |
|---|---|---|---|
| grammar-en | CoNLL-14 official M², full set | F0.5 **0.522** | 2.49× LanguageTool (0.168) |
| grammar-fr | held-out corruption | F0.5 0.811 | — |
| grammar-es | held-out corruption | F0.5 0.620 (P 0.92) | — |
| grammar-de | held-out suite + LLM-judge gate | published | see model card |
| grammar-ru | held-out corruption (812 pairs) | F0.5 0.385 (P 0.71) | 16.6× the previous ru weights |
| grammar-cjk | zh-Hans / zh-Hant held-out | 0.639 / 0.796 | one shared 3-script model |
| grammar-ko | held-out single-error (1,582 pairs) | F0.5 **0.394** (P 0.61) | 3.5× the cjk-line ko weights |

Real-error benchmarks (dense learner errors, much harder than the
synthetic slices): ko real corpus (23,333 sents) 0.235 · ja JWTD 0.158
· zh NLPCC 0.070 — these quantify the gap to real-learner performance
and are the target for the real-corpus training arms (license-gated).

### The en reproduction closure

The 0.522 flagship could NOT be re-derived from surviving data +
recipes under the current stack: 6ep 0.311 / 8ep 0.299 / within-run
fusion 0.296 / flagship-data 0.075 (old-stack pin included). grammar-en
(0.522) stands as the best en artifact; the v8 line (0.289-0.311) is
the reproducible frontier under today's stack. Lesson recorded: an
artifact's data lineage is part of the artifact.

### Spelling-suggestion board (suggesters-benchmark, en nonword top-1/3/5)

kotoshu 86.4 / 94.4 / 95.7 — competitive with SymSpell 85.4 and
Hunspell 78.5/93.6/95.1. The quill lane (noisy-channel, merged
2026-11-11) leads at 95.2 / 98.2 / 98.45; closing that gap is the
queued ranking work item.

### Corpus quality law (measured, twice)

Class balance in the training corpus decides the model: the ko v1
pack's spacing-skew trained merge/delete spam (0.047) while the
balanced v2 pack won the gate at 0.394; ru non-word corruptions scored
R 0.000 across three model generations until the attested-form law
landed. Data design > recipe tuning.
