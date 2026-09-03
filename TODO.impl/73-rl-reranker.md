# 73 — RL-Trained Reranker (adopt-later C2)

From [68-sota-adoption.md](68-sota-adoption.md) item C2. The GLM-5.3
recipe scaled down: RL on **binary verifiable rewards** — spelling
correction is verifiable by construction (output == reference)
([GLM tech report](https://arxiv.org/html/2602.15763v1)).

## Goal

Train tier-sized reranker weights (not LLMs — the existing embedding +
a small scorer head) with RL where the reward is exact-match on typo
corrections, replacing heuristic rerank scoring with a learned policy
that keeps our latency/memory envelope.

## Preconditions (all three, no exceptions)

1. Conformance vectors exist and are stable (plan 67 M3 output) — the
   reward must be measurable against golden fixtures.
2. A training-pipeline owner is named (compute, seeds, checkpoints).
3. The corpus bench (plan 69) provides the train/eval split hygiene:
   train on synthetic keyboard typos, eval on GitHub Typo Corpus.

## Tasks (when unblocked)

1. `training/` workspace (likely models repo or a new kotoshu-training
   repo — owner decision): policy = current cosine scorer + small MLP
   head over (candidate, context) features; GRPO-style or simple REINFORCE
   with exact-match reward; baselines from the corpus bench.
2. Gate: beat the shipped rerank on corpus top-1 by ≥ 5 points without
   regressing rank_corr gates; same ONNX exportability; int8-able.
3. Distribution through the existing registry as new model versions —
   never a silent replacement.

## Acceptance

- Trained artifact passes all existing eval gates + corpus bench lift;
  training reproducible from committed seeds and data manifests.

## Status

_Planning — gated_ on plan 67 M3 conformance vectors + named training
owner. Do not start before both exist.
