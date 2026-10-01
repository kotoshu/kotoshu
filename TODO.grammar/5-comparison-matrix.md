# 5 — The SOTA comparison matrix: competitors, our results, the path

DIRECTION (2026-09-30, owner decision): NO LanguageTool data. Their
LGPL and attribution complexity are rejected outright. Every rule is
ORIGINAL work in our own YAML DSL — no XML, no conversion, no
attribution. The LT XML loader (TODO.grammar/3, PR #245) is
superseded; it stays on its branch as reference only.

## The matrix (SOTA title run)

| solution | en rules | license | client-side | context model | measured quality |
|---|---|---|---|---|---|
| **kotoshu (rules)** | 180 original (en 150 + de/es/fr) | BSD-2 (ours, no attribution) | yes, <5 ms/sentence | rule-based tagger + recursive matcher | 180/180 own examples fire; 0.0% FP on clean corpus |
| **kotoshu (hybrid, measured)** | 180 + closed-class tagger | ours | **yes — 78.2 MB int8** | tagger detects (99.25% sent), rules fix (0% FP) | **F0.5 0.827 vs LT 0.432 on identical sentences** (2,392, token-level) |
| LanguageTool | ~1,700 en (+2,000 de...) | LGPL-2.1+ (data + code) | yes (Java) | hand rules + their tagger | ~100% of own examples (by construction) |
| Grammarly | closed | proprietary | no (cloud) | large neural + rules | closed; de facto market quality bar |
| GECToR (2020, literature) | learned | research | borderline (350 MB) | transformer tagger | BEA-2019 F0.5 ~56-65 |
| T5-11B / LLM GEC (2022-2025) | learned | varies | no (cloud) | seq2seq | BEA-2019 F0.5 ~70-78 |
| Hunspell / cspell | 0 grammar | various | yes | none | spelling only — not a grammar competitor |

## The FULL-TAXONOMY benchmark (CoNLL-2014 test, official M2 scorer, 2026-10-01)

Real learner errors, all 28 types, 1,312 sentences, beta 0.5 — the
market's home field. OUR ROWS MEASURED TODAY, same gold, same scorer:

| system | P | R | F0.5 | local? |
|---|---|---|---|---|
| T5-11B (published) | ~0.69-0.79 | ~0.33-0.40 | **~72-75** | no (42 GB) |
| GECToR (published) | ~0.53-0.57 | ~0.25-0.33 | **~56-58** | borderline |
| **LanguageTool 6.6 free (measured)** | **0.305** | **0.060** | **0.168** | yes (Java) |
| **kotoshu hybrid (measured)** | **0.143** | **0.029** | **0.080** | **yes (78 MB)** |

Read honestly: on the full error distribution WE LOSE TO EVERYONE —
LT doubles us; GECToR is 7x; T5-11B is 9x. The in-distribution win
(F0.5 0.827 vs LT 0.432 on our 7-class taxonomy) does NOT transfer:
our closed classes cover a slice of the real error mass, the tagger
overfires off-distribution ("because of" -> "have"), and there is no
generative tail. Both results are true; the market benchmark is this
one. The path from 0.08 toward 56+: (1) tagger trained on REAL error
data (BEA/FCE train, public) not synthetic injection alone, (2) grow
closed classes toward the CoNLL type inventory, (3) the <200 MB
constrained rewriter for the flagged residual. Reproducible:
scripts/grammar_headtohead.rb + the m2scorer pipeline.

## What SOTA requires (definition)

1. F0.5 >= LanguageTool on the SAME public test set (BEA-2019 test
   split; public data, evaluation use is unambiguous)
2. Unique capabilities LT lacks: 3-API parity (Ruby/Rust/TS from one
   YAML), native-gem simplicity (no Java), variant-pure CJK models,
   cross-script romanization channel
3. Every number traces to a committed frozen report
4. No third-party rule data — nothing to attribute, nothing to
   relicense

## Our measured results (frozen, this branch)

| metric | value |
|---|---|
| original rules | 180 (en 150 + de/es/fr 10 each; 12 files) |
| own bad examples fired | 180/180 (gate spec, all 4 languages) |
| own good examples FP | 0/102 |
| clean-corpus FP (30 prose sentences) | 0.0% |
| local tagger size (int8 ONNX, measured) | 78.6 MB — 2.5x under the 200 MB budget |
| Rust/Ruby conformance | 15 sentences, 29 errors, exact replay |
| **head-to-head vs LanguageTool 6.6 (free desktop), identical 2,392 injected sentences, token-level** | **hybrid: P 0.807 / R 0.919 / F0.5 0.827 — LT: P 0.720 / R 0.166 / F0.5 0.432 — rules-only: 0.305** |
| hybrid latency | local Ruby onnxruntime, ~6 ms/sentence |
| check latency | < 5 ms/sentence (rule-based, no model) |

## Path to success (ordered)

1. [done] Engine wiring: Kotoshu.grammar_check, char-offset errors
2. [done] 150 dual-gated original rules
3. Rust port + conformance vectors (same YAML, zero XML)
4. TS/server: grammar flag on the check endpoint
5. Grow to ~400 rules by error class (the audit harness scales)
6. BEA-2019 test evaluation of rules-only (the honest baseline number)
7. GECToR-style tagger distilled from a BART/T5 teacher (our own
   training, our own weights) — the hybrid that takes F0.5 past LT
8. de/es/fr original rule sets (~30 each), then ja/ko/zh research
9. Publish the matrix with frozen reports per cell
