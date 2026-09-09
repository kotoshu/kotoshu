# Plan 115 — The hybrid retrieval thread: price it before believing it

## Why
Plan 114's reject left one survivor on record: C-retrieve (0.5 MB bi-encoder)
+ fastText-rescore beat the FULL tier on top-1 AND top-5 across all four
real bench components. Before any ship decision, its costs and its
dependence on synthetic-heavy slices must be priced honestly.

## Work (models repo)
1. Price the retrieval half: per-language 100k x 256 vocab matrix (fp16 +
   int8 variants) — build for en, measure size, build time, top-k
   retrieval latency, and quality vs the brute-force sweep on the frozen
   C-benchmark.
2. Quality stress: score the hybrid ONLY on real-pair components
   (en 2509; de/ru/es real n are tiny — report with CIs, no synth pooling
   for the verdict).
3. Verdict per the plan-114 rule: ship as opt-in registry resource only
   on clear wins with no regression; honest reject otherwise. No registry
   changes on reject.

## Status
Pending
