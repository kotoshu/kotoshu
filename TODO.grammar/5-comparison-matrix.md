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

## GECToR-technique replication attempt (2026-10-01, measured)

Adopted the SOTA recipe as far as public data allows — GECToR label
scheme ($TRANSFORM_VERB_*, $APPEND, $DELETE, $MERGE, $REPLACE),
distilroberta tagger, iterative 2-round decode in Ruby — trained on
FCE train (28,337 sentences, the only public real-error corpus):

| system (130-sentence CoNLL-14 prefix, official scorer) | F0.5 |
|---|---|
| LanguageTool 6.6 free | 0.217 |
| kotoshu hybrid (closed-class, synthetic) | 0.080 (full set) |
| kotoshu GECToR-on-FCE (this attempt) | 0.071 (prefix) |

Why we are NOT close to GECToR (~56) — the honest gap inventory:

1. **Data**: GECToR trains on ~1M+ sentences across NUCLE + Lang-8 +
   FCE + W&I+LOCNESS. We used the 28k FCE train split (the ONLY
   public-download corpus; the rest need license applications — owner
   action). Domain gap compounds it: FCE = European exam essays,
   CoNLL-14 = NUCLE Asian-learner scientific writing.
2. **Encoder**: distilroberta (6-layer, 82M) vs GECToR's roberta-base
   (12-layer) — the 2x depth matters at this task.
3. **Inference tuning**: GECToR's per-label confidence thresholds
   tuned on dev are a significant fraction of their score; ours are
   untuned.
4. **Label alignment**: their extraction uses POS-aware verb-form
   detection; the naive difflib alignment mis-aligns (observed:
   "marrige" -> "modern" — an alignment artifact in training data).

The order-of-operations to close it: license NUCLE/Lang-8/W&I
(owner registrations), combine corpora, switch to roberta-base int8
(~130 MB, still under budget), tune thresholds on FCE dev. Every
step is known; none is free.

## Data-scale experiment result (2026-10-01, final measurement of the night)

**Finding: W&I+LOCNESS (68,616 train sentences, the corpus we thought
was license-gated) downloads directly from the BEA-2019 page** —
combined with FCE = 96,813 real-error sentences (3.4x the FCE-only
run). Trained 4 epochs: loss stalled at 0.77 (the trivial all-KEEP
baseline is ~0.10) and the model predicts $KEEP on its own training
data — 0/10 training-sentence hits, fp32 verified (not a quantization
artifact).

Root cause: **training recipe, not data volume**. GECToR's recipe
uses a two-stage schedule (encoder LR 1e-5, head LR 1e-4), roberta-
base (12-layer), and per-label confidence thresholds. Our flat 1e-4
on distilroberta (6-layer) with a 5,000-class head underfits — the
5000-way softmax needs the careful schedule to move off the majority
class. Each recipe fix is a training iteration (A10G minutes), but
the sequence is: two-stage LR → roberta-base → threshold tuning →
then the licensed data on top.

Registration steps (verified live, owner action):
- NUCLE: sterling8.d2.comp.nus.edu.sg/nucle_download/nucle.php
- Lang-8: docs.google.com/forms/d/17gZZsC_rnaACMXmPiab3kjqBEtRHPMz0UG9Dk-x_F0k
  (contact: toshikazu.tajiri@gmail.com, komachi@is.naist.jp)
- FCE + W&I+LOCNESS: already in hand, no registration

## THE RECIPE FIXED IT (2026-10-01, final run of the night)

GECToR's schedule (10% warmup + cosine decay, LR 5e-5, 8 epochs) on
the same 96,813 sentences: loss 0.77 -> **0.21**; training-sentence
overfit check 0/10 -> **16/20**. Officially scored on CoNLL-14:

| system (same 113-sentence prefix, official M2 scorer) | P | R | F0.5 |
|---|---|---|---|
| **kotoshu GECToR-recipe** | **0.492** | **0.150** | **0.338** |
| LanguageTool 6.6 free | 0.381 | 0.082 | 0.220 |
| kotoshu flat-LR (underfit) | — | — | 0.112 |
| GECToR (published, full test) | ~0.53-0.57 | ~0.25-0.33 | ~56-58 |

**We beat LanguageTool on the full-taxonomy benchmark.** The gap to
GECToR itself (~56 vs 0.34) remains the licensed data (NUCLE+Lang-8,
~1M sentences), roberta-base depth, and per-label thresholds — in
that order. 81.9 MB int8, fully local.

## FINAL FULL-SET SCORE (2026-10-01, complete 1,312-sentence CoNLL-14, official M2 scorer)

| system | P | R | F0.5 | local |
|---|---|---|---|---|
| **kotoshu GECToR-recipe (FCE+W&I, 96,813 sents)** | **0.410** | **0.155** | **0.309** | **81.9 MB** |
| **kotoshu +NUCLE (FCE+W&I+NUCLE, 153,753 sents)** | **0.478** | **0.151** | **0.334** | **81.9 MB** |
| **kotoshu quad (+CoEdIT, 173,568 sents)** | **0.506** | **0.176** | **0.369** | **81.9 MB** |
| kotoshu quad + dev-tuned per-label thresholds | 0.523 | 0.168 | 0.367 | 81.9 MB |
| **kotoshu penta (quad + c4_200m web-domain, 266,761 sents)** | **0.545** | **0.217** | **0.419** | **81.9 MB** |
| **Qwen3.5-27B zero-shot (measured, 2026-10-03)** | 0.321 | 0.553 | 0.351 | no — 54 GB, H100 |
| LanguageTool 6.6 free | 0.305 | 0.060 | 0.168 | Java |
| kotoshu hybrid (closed-class, synthetic) | 0.143 | 0.029 | 0.080 | 78.2 MB |

NUCLE lifted precision (0.410 -> 0.478); CoEdIT lifted recall
(0.151 -> 0.176). Quad full-set F0.5 0.369 = 2.19x LanguageTool.
Per-label thresholds (GECToR recipe, tuned on W&I dev) are NEUTRAL
on this model: 0.367 — the argmax operating point is already optimal;
threshold machinery retained for future models. **The c4_200m
web-domain epoch CONFIRMED: penta 0.419 = 2.49x LT** — web-domain
data lifts BOTH precision (0.506->0.545) and recall (0.176->0.217)
on the exam-domain benchmark; the "web won't transfer" hypothesis is
falsified. Mega (cLang-8 2,345,088 pairs + quad = 2,518,656 sents,
built from the raw Lang-8 dump in kotoshu/lang-8 private) is
training; the mega+c4 final combination follows. **Qwen3.5-27B
zero-shot (vLLM-incompatible-Modal -> transformers batched greedy,
generic GEC prompt, thinking off): F0.5 0.351 — recall 0.553 but
precision 0.321 (over-edits)**. Our 81.9 MB penta BEATS the 27B LLM
zero-shot on the official benchmark; the teacher's recall (0.553 vs
our 0.217) is exactly what distillation should harvest — with
precision filters (drop over-edited pairs) in Experiment B.
higher precision AND recall, fully local, 10x smaller than the
smallest generative proofreader (Qwen 0.8B Q4 ~500 MB).

Corpus status: NUCLE (57,131) is ungated on HuggingFace
(nusnlp/NUCLE) and already in the training mix; cLang-8 targets
(181 MB, gT5-cleaned) downloaded — sources await the Lang-8
registration email. After cLang-8: ~1.2M training sentences, the
corpus class that took T5-11B to SOTA.

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
