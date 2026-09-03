# 74 — Distilled Reranker (adopt-later C3)

From [68-sota-adoption.md](68-sota-adoption.md) item C3. The DeepSeek
V4 recipe: consolidate specialists into a student via **on-policy
distillation (reverse KL)** — the exact recipe for distilling a large
teacher reranker into tier-sized weights
([report](https://arxiv.org/html/2606.19348v1)).

## Goal

Where RL (plan 73) learns from binary rewards alone, distillation
transfers a strong teacher's **soft judgments** — a large embedding or
LLM scoring the same candidate lists — into the small scorer, then the
RL stage (73) fine-tunes on top. Teacher runs offline during training
only; nothing large ships.

## Preconditions

Same as plan 73, plus a teacher selection (open-weights embedding
model or API LLM with a cost cap — owner decision; API usage must be
budgeted and never in CI).

## Tasks (when unblocked)

1. Teacher scoring pass over the training corpus (offline, one-off,
   committed scores) — candidate lists identical to what the engine
   produces at runtime.
2. Student = same architecture as plan 73's policy; loss = reverse KL
   to teacher distribution over candidates; then plan 73's RL stage.
3. Gate: student ≥ teacher-within-1-point on corpus top-1 while fitting
   the tier envelope; all existing gates pass.

## Status

_Planning — gated_ behind plan 73's preconditions + teacher decision.
Sequence: 74 distill → 73 RL fine-tune, one pipeline.
