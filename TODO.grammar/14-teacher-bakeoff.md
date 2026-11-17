# 14 — Teacher bake-off: distilled-from-which LLM

Measured 2026-10-03, all arms identical protocol: same 1,312
CoNLL-14 sources, generic GEC prompt, temperature 0, official M2
scorer. Self-hosted on Modal H100 (transformers batched; vLLM 0.30
breaks on Modal with a torch stable-ABI dispatcher error).

| teacher | F0.5 | P | R | cost |
|---|---|---|---|---|
| **GLM-5.3-Flash (API)** | **0.3563** | 0.328 | 0.543 | API points (weekend 50%) |
| Qwen3.5-122B-A10B (4xH100) | 0.3535 | 0.326 | 0.539 | very high |
| Qwen3.5-27B (1xH100) | 0.3506 | 0.321 | 0.553 | moderate |
| Qwen3.5-9B (1xH100) | 0.3398 | 0.313 | 0.520 | low |
| Qwen3.8-27B (newer gen) | 0.3297 | 0.305 | 0.490 | moderate |
| Qwen3.5-27B, minimal-edit prompt | 0.3183 | 0.297 | 0.448 | — |

## Findings

1. **GLM-5.3-Flash is the teacher**: best F0.5 AND best precision of any
   arm, recall in the top cluster. Called via the z.ai Anthropic-compatible
   endpoint (coding-plan key; the OpenAI-compat /paas/v4 route has no
   pay-per-token balance — code 1113). Reasoning always on; the answer is
   the `text` content block, `thinking` blocks ignored
   (scripts/glm_teacher.py).
2. **Teacher quality saturates at 27B**: the 122B (4.5x params, 4x
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

Teacher: GLM-5.3-Flash (bake-off winner). COMPLETE 2026-10-04:
35,705/35,706 corrected (one address line unfixable — safe no-op
fallback), verify split: **12,040 verified (33.7%)** — teacher
restored the known-clean original exactly — 22,697 variant (<=2
token delta, kept with ground-truth target), 969 dropped (teacher
rewrote; discarded). gector_prep labels (src=corrupted, tgt=clean
ground truth) -> 34,737 pairs -> Run C corpus
mega_c4_distill_2646k.jsonl (2,646,586 sentences) on the volume.
Rate-law learned: coding-plan request cap ~6-8 concurrent (error
1302); results flush every 50 to glm_ck_distillFull.json.

Owner law: teacher licenses are irrelevant ("we can always teach");
selection is quality/throughput only.
