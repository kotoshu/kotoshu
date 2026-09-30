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

## Status

NOT STARTED. Prerequisite: TODO.grammar/2 rule coverage for the
residual definition, then training on Modal (A10G, existing infra).
