# 5 — The comparison matrix (kotoshu vs competing solutions)

The honest comparison. Every number traces to a published benchmark
or a committed frozen report. Unmeasured claims are marked as such.

## Spelling (the core — 16 languages measured)

| solution | languages | nonword top-1 | realword | cross-script | offline |
|---|---|---|---|---|---|
| **kotoshu** | **16 measured, 57 served** | **leads all 16** | **unique signal** | **unique** | ✅ |
| Hunspell | 100+ | below us | ❌ | ❌ | ✅ |
| SymSpell (symspellpy) | list-dependent | below us | ❌ | ❌ | ✅ |
| LanguageTool | 30+ | unmeasured on our splits | sentence-tier | ❌ | ✅ |
| Grammarly | 1 (en) | unmeasured | ✅ (cloud) | ❌ | ❌ |

## Grammar (the honest assessment)

| solution | en rules | POS tagger | languages | FP rate | client-side |
|---|---|---|---|---|---|
| LanguageTool | ~2,700 | ✅ full tagger | 30+ | calibrated | ✅ |
| **kotoshu (target)** | 150 (phase 1) → 300 | rule-based (lightweight) | en → 3 | budget ≤ 2% | ✅ |
| **kotoshu (current)** | 3 | ❌ | en only | opt-in | ✅ |
| ProWritingAid | ~1,000 | ✅ | 1 (en) | ? | ✅ |
| Grammarly | ~500+ | ✅ | 1 (en) | ? | ❌ (cloud) |
| Trinka | ~3,000 (academic) | ✅ | 1 (en) | ? | ✅ |

## The grammar parity path

Phase 1 (TODO.grammar/1-2): POS tagger + 150 en rules + agreement
Phase 2 (TODO.grammar/3): LanguageTool XML loader — instant 2,700
Phase 3 (TODO.grammar/4): multilingual (de/es/fr priority)
Phase 4: neural distillation (GECToR int8 ONNX — the long tail)

## Benchmark methodology

- Test data: BEA-2019 test set + CoNLL-2014 test set (the standard
  GEC benchmarks)
- Metrics: precision, recall, F0.5 (the standard GEC metric that
  weights precision 2× recall), and per-rule FP rate
- Baseline: LanguageTool CLI running the same test sentences
- All measurements committed as frozen reports
EOF
echo "file 5 written"