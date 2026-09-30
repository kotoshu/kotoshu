# 9 — Neural grammar: GECToR tagger distilled FROM a BART/T5 teacher

The neural layer is the core of context-dependent grammar correction,
not an optional extra. Rules catch local patterns; agreement across
intervening phrases, tense sequences, and word order need a model
that sees the whole sentence. And detection alone is not a product —
the checker must produce the CORRECT correction, which is generation.

## Why the tagger, not seq2seq, is what we ship

| model | P | R | F0.5 | size | latency | client-side |
|---|---|---|---|------|---------|-------------|
| BART-large (fine-tuned GEC) | ~75 | ~53 | ~69 | ~1.6 GB | ~500 ms | no |
| T5-11B | ~82 | ~55 | ~74.6 | ~42 GB | seconds | no |
| GECToR-XLNet | ~72 | ~33 | ~58 | ~350 MB | ~50 ms | borderline |
| **GECToR distilled, int8** | ~68 | ~31 | ~53 | **~50 MB** | **~20 ms** | **yes** |

- BART/T5 are the TEACHERS: highest accuracy, cloud-scale only.
- The GECToR tagger IS a correction generator — per-token tags
  ($KEEP, $REPLACE_were, $APPEND_the, $DELETE, $MERGE_A_SPACES_B) —
  decoded iteratively (2-3 passes). It sees the full sentence through
  the transformer encoder, so it captures context-dependent grammar,
  and its corrections come out as concrete strings.
- Distillation: train the small tagger on a large teacher's OUTPUT
  (pseudo-corrections of raw text) plus the BEA-2019/W&I+LOCNESS gold
  data. The teacher's knowledge flows in; the tagger's size stays.

## Pipeline

1. Teacher: a fine-tuned BART-large GEC checkpoint (public HuggingFace)
2. Training data: BEA-2019 (W&I+LOCNESS, public) + teacher
   pseudo-labels on raw corpora
3. Student: distilroberta-sized tagger (66-83M params)
4. int8 quantization → ONNX (our existing converter + runtime)
5. Serve as `models/{lang}/gec-taggers.onnx` through the existing
   model cache; the neural layer plugs into the checker as a strategy

## Three-API surface

- Ruby: onnxruntime (existing soft dependency)
- Rust: ort/onnxruntime crate — same model file
- TS: onnxruntime-web WASM with int8 (fits the memory ceiling)

## Acceptance

- en F0.5 ≥ 50 on BEA-2019 test (tagger-distilled, int8)
- latency ≤ 25 ms/sentence client-side
- every flagged error carries a concrete correction string
- rules run first; the tagger fires on the residual (hybrid)

## The local-model constraint (owner, 2026-09-30)

Users require a LOCAL model under 200 MB — content never leaves the
machine. The budget:

| component | size (int8) |
|---|---|
| distilroberta-base encoder (6L, 82M) | ~85 MB |
| GECToR label vocabulary (~4k edits) | ~10 MB |
| tokenizer | ~0.7 MB |
| **total** | **~96 MB — fits with 2x headroom** |
| latency | ~30-90 ms/sentence CPU |

## The license-pure training pipeline (nothing to attribute)

No real-world GEC corpora (licensed, attribution-heavy). We generate
our own training data:

1. public-domain clean text (Gutenberg and similar PD sources)
2. `scripts/error_injector.rb` (on the rules branch) — injects OUR
   error taxonomy (agreement, of/have, capitalization, articles,
   morphology, spelling tweaks) as token-aligned clean/corrupted/edit
   triples
3. `scripts/train_tagger_modal.py` — distilroberta tagger, GECToR
   labels from the edits ($KEEP/$REPLACE_x/$DELETE), int8
   dynamic-quantized ONNX export with a hard <200 MB gate
4. runtime: onnxruntime (Ruby), ort (Rust), onnxruntime-web
   (browser) — fully local, no cloud, ever

Synthetic-errors-only training is how GECToR itself reached most of
its accuracy; taxonomy alignment specializes the tagger in exactly
the residual classes the rules cannot reach.

## Status — SCALED RUN MEASURED (2026-10-01)

| metric | value |
|---|---|
| training | 3,068 PD pairs, 6 epochs, ~4 min A10G |
| int8 model | **79.4 MB** (budget 200 MB) |
| dev (355 pairs, sentence-disjoint) | token accuracy 96.6% |
| corrupted-sentence detection | ~86% (13.8% predicted all-KEEP) |
| end-to-end exact correction | **0%** — honest limit |
| local Ruby inference (onnxruntime int8) | **5.7 ms/sentence**, clean text silent |

Reading: DETECTION is learned at smoke scale (right token flagged,
clean text quiet). EXACT-REPLACEMENT is not — the label vocab is the
open vocabulary of clean words (1,664 labels from 3k pairs; GECToR
trains on 500k+). Two paths forward, both in-design:

1. scale the injector (Gutenberg has 70k books; 100k+ pairs is a
   download + one Modal run)
2. closed-class hybrid: the tagger predicts the ERROR CLASS, our
   rules/morphology generate the fix — bounded labels, fits the
   existing suggestion machinery

labels.json ships with the model (tie-ordered Counter map; consumers
must not rebuild it — PR #249).

## CLOSED-CLASS HYBRID — THE MEASURED ANSWER (2026-10-01)

Open-vocab $REPLACE labels do NOT converge (0% end-to-end at 3k AND
27k pairs — the label set IS the open vocabulary of clean words,
4,001 labels at scale). The closed-class variant converges hard:

| run | labels | int8 | token acc | class acc (corrupted) | sentence detection |
|---|---|---|---|---|---|
| 3k open | 1,665 | 79.4 MB | 96.6% | — | 86% |
| 27k open | 4,001 | 81.1 MB | 98.8% | — | 80.5% |
| **27k closed** | **8** | **78.2 MB** | **99.2%** | **95.4%** | **99.25%** |

Architecture (final): the tagger detects WHICH token is wrong and
NAMES the error class (8 classes mirroring the rule taxonomy); the
RULES and morphology verbs generate the concrete fix. Neural
detection + deterministic, dual-gated correction — 78 MB, fully
local, license-pure end to end.
