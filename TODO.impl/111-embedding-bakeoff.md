# Plan 111 — The embedding bake-off: is fastText still the right model?

## Why
Our gates prove int8 near-lossless RELATIVE to fastText — but fastText is
2017-era, context-blind, and our own numbers cap intended-top-5 near 0.21
on hard English typos even with buckets. The eval harness (keyboard-aware
grids, typo corpora, frozen gates) is the asset; use it to test successors.

## Work (models repo; eval only — no registry release without a verdict)
1. Baseline: current mini/fluency+buckets through the existing gates.
2. Candidate B: fastText + small cross-encoder rerank over (context,
   candidate) pairs — ONNX-exportable distill class, 15-30 MB int8.
3. Candidate C: purpose-trained typo bi-encoder over the vendored
   github-typo-corpus (train/eval split strictly by repo).
4. Candidate D: ModernBERT-class small encoder, same size budget.
5. Report: gates table per candidate per language (en de ru es minimum),
   size, latency-per-suggest, and a ship/reject verdict with the same
   discipline as int4 (reject on data is a complete outcome).

## Verification
Every number from the existing harness, unweakened; frozen corpora; no
registry changes in this plan.

## Status
Executed 2026-09-09 — models PR #25 merged. VERDICT: fastText stays.
B (MiniLM cross-encoder rerank) REJECT — loses 4/4 languages (en 0.194 vs
fluency 0.252 top-5; slate recall caps en at 0.43; context ablation
negative). D (ModernBERT-base) REJECT — representation failure (top-5
0.03-0.24), 5x size cap. C (0.5 MB char-BiGRU typo bi-encoder, 5.2
ms/suggest) REJECT as drop-in but PROMISING — beats the full tier on the
strict repo-clean subset for en and de; open thread needing non-en data,
a bigger clean bench, and a top-1 story. Full ladders in
eval/reports/bakeoff-v1.md.
