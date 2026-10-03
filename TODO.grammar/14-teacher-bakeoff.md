# 14 — Teacher bake-off: distilled-from-which LLM

Measured 2026-10-03, all arms identical protocol: same 1,312
CoNLL-14 sources, generic GEC prompt, temperature 0, official M2
scorer. Self-hosted on Modal H100 (transformers batched; vLLM 0.30
breaks on Modal with a torch stable-ABI dispatcher error).

| teacher | F0.5 | P | R | cost |
|---|---|---|---|---|
| Qwen3.5-122B-A10B (4xH100) | 0.3535 | 0.326 | 0.539 | very high |
| **Qwen3.5-27B (1xH100)** | **0.3506** | 0.321 | **0.553** | moderate |
| Qwen3.5-9B (1xH100) | 0.3398 | 0.313 | 0.520 | low |
| Qwen3.8-27B (newer gen) | 0.3297 | 0.305 | 0.490 | moderate |
| Qwen3.5-27B, minimal-edit prompt | 0.3183 | 0.297 | 0.448 | — |
| GLM-5.3-Flash (API) | blocked: key valid, account balance empty (code 1113) | | | |

## Findings

1. **Teacher quality saturates at 27B**: the 122B (4.5x params, 4x
   GPUs) ties the 27B. Scaling does not buy proofreading quality
   zero-shot — the LLM's over-editing discipline is the binding
   constraint, not capacity.
2. **Newer is not better**: Qwen3.8-27B is WORSE than 3.5-27B here
   (R 0.490 vs 0.553).
3. **Prompt engineering does not fix over-editing**: the minimal-edit
   prompt lost BOTH precision and recall.
4. **Teacher selection: Qwen3.5-27B** for quality; **9B** for bulk
   generation economics (3.9% quality cost, ~3x throughput).
5. For a TEACHER the metric is recall + edit discipline (our
   alignment filters handle precision); all LLMs cluster at R
   0.45-0.55 zero-shot — 2-3x our tagger's recall, which is the
   point of distillation.

## Distillation (Phase 2, in flight)

35,706 typed corruptions of clean c4 sentences (corruption generator:
scripts/corrupt_and_distill.py — ArtOrDet/Prep/Nn/SVA/Wci, the five
recall-starved classes from the error analysis), each with known
ground truth. Teacher corrects; pairs where the teacher restores the
known-clean original are "verified" (highest-signal), small deltas
are "variant". Output becomes the distill corpus layered on mega+c4.

Owner law: teacher licenses are irrelevant ("we can always teach");
selection is quality/throughput only.
