# 70 — Confidence Cascade in the Semantic Path

Executes adopt-now item A3 of
[68-sota-adoption.md](68-sota-adoption.md) in THIS repo (the gem),
following the published hybrid dictionary+neural architecture
([arxiv 2410.23514](https://arxiv.org/html/2410.23514v1): dictionary
first, neural rerank only for uncertain candidates — and their finding
that the confidence boundary is where the quality lives).

## Goal

Formalize what the semantic path already half-does: the ONNX rerank
runs **only when the traditional composite strategy is not already
confident**, with an explicit, configurable threshold — cutting model
loads and latency on the happy path without changing results where the
dictionary is certain.

## Design

1. `Configuration::SCHEMA` gains `semantic_cascade_threshold`
   (float, default `1.0` — preserving today's always-rerank behavior;
   ENV `KOTOSHU_SEMANTIC_CASCADE_THRESHOLD` automatic via the schema).
2. In `Suggestions::Generator` (or `SemanticStrategy`), when the
   composite strategy's top candidate confidence ≥ threshold, skip the
   semantic rerank for that suggestion set; log the skip under debug
   metrics.
3. `docs/` note + README section: what the threshold means, how to
   tune it (0.0 = never rerank, 1.0 = always), and that measured
   guidance comes from the eval harness once plan 69's corpus bench
   lands.
4. Spec coverage: behavior with threshold 1.0 (identical to today),
   0.0, and a mid value — real model instances per the global no-doubles
   rule; onnx-dependent specs tagged `:onnx` per the existing opt-in
   convention.

## Acceptance

- Default behavior is byte-identical to today (existing suite green).
- A mid-threshold spec proves the skip happens exactly when confidence
  ≥ threshold, and never otherwise.
- `kotoshu check --verbose` surfaces cascade-skip counts.

## Dependencies

- Independent of 69/71; tuning guidance arrives from 69's corpus bench.
- Performance numbers for the README: measure rerank skip rate on the
  existing example corpus at thresholds {1.0, 0.9, 0.8}.

## Status

_Planning._
