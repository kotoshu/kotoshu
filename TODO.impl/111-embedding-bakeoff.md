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
Pending
