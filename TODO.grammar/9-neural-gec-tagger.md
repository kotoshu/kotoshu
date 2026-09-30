# 9 — Neural GEC tagger (GECToR distillation — the SOTA push)

## What GECToR does

GECToR (Omelianchuk et al., 2020) tags each token with a correction
label instead of generating the full corrected sentence:

- $KEEP (no change)
- $APPEND_word (insert after this token)
- $DELETE (remove this token)
- $REPLACE_word (replace with word)
- $MERGE_WITH_NEXT (combine tokens)

Iterative refinement: apply tags, re-tag, repeat until stable
(usually 2-3 iterations). This is faster than seq2seq and works
client-side when quantized.

## Academic SOTA reference

| model | test set | P | R | F0.5 | size | speed |
|-------|----------|---|---|------|------|-------|
| GECToR-RoBERTa | BEA-2019 | 77.9 | 40.2 | 65.3 | ~350 MB | ~50ms |
| GECToR-XLNet | CoNLL-14 | 71.9 | 33.3 | 58.1 | ~350 MB | ~50ms |
| T5-11B | BEA-2019 | 82.1 | 55.2 | 74.6 | ~42 GB | ~500ms |
| GPT-4 (few-shot) | BEA-2019 | ~85 | ~60 | ~78 | cloud | seconds |
| **GECToR int8 distilled** | BEA-2019 | ~72 | ~35 | ~56 | **~50 MB** | **~20ms** |

Our target: the distilled row — client-side, fast, within 10 points
of the best cloud model.

## Distillation pipeline

1. **Train**: fine-tune a small transformer (e.g. distilroberta-base,
   66M params) on the BEA-2019 + W&I+LOCNESS training data
2. **Distill**: knowledge distill from a larger teacher (roberta-large)
3. **Quantize**: int8 dynamic quantization (our existing ONNX pipeline)
4. **Export**: ONNX (our existing converter infrastructure)
5. **Serve**: the existing kotoshu model cache + ONNX runtime

## What we already have

- ONNX export infrastructure: ✅ (used for fasttext models)
- int8 quantization: ✅ (TODO.sota/6 quantize_lane.py)
- The model cache + registry: ✅ (serves 57 languages)
- The suggestion pipeline: ✅ (the neural layer plugs in as a strategy)

## What we need

- Training data: BEA-2019 + W&I+LOCNESS (~34k annotated sentences, public)
- Training compute: Modal GPU (A10G, ~$0.10-0.50/run)
- Teacher model: roberta-large fine-tuned on GEC (available on HuggingFace)
- Student model: distilroberta-base or a custom small architecture

## Implementation order

1. English first (the BEA-2019 training data is public)
2. The model ships as `models/en/fasttext.en.gector.onnx`
3. Multi-language: either per-language models or one multilingual model
   (mBERT/XLM-R distilled — larger but covers more languages)

## The three-API path

- **Ruby**: the ONNX runtime (existing infrastructure)
- **Rust**: the tract/onnxruntime crate (same model file)
- **TS**: WASM with onnxruntime-web (int8 quantized, under the memory
  ceiling since GECToR models are small)
