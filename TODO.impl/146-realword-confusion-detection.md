# Plan 146: real-word confusion-set detection in the analyzer

## Status: proposed (blocked on models plan 15 calibration)

## Problem

`SemanticAnalyzer#analyze` skips every in-vocab token
(`next if valid_word?(word)`, semantic_analyzer.rb:67) — detection is
dictionary membership, so the models only ever rank corrections for
words already flagged as non-words. An in-vocab word that is wrong in
context ("I want to each rice") is never questioned: the semantic
machinery (context windows, cosine reranking, KTM1, fluency) sits
behind a dictionary gate it never crosses. That inverts the product
promise — a checker whose detection is a lookup is a dictionary with
good autocomplete attached.

## What

- New `Analyzers::RealWordAnalyzer` (separate class, MECE with the
  non-word path; `SemanticAnalyzer` stays as-is): for each in-vocab
  token with a non-empty confusion set (from the confusion-table
  resource), score the word vs its confusion candidates in context
  and emit a `real_word` error when the margin clears the language's
  frozen threshold.
- Resource: `confusion-table` registry type (downloaded/cached like
  other model resources; `ResourceManager#setup?` gains the resource
  branch; `languages_setup` unions it in — absent table ⇒ analyzer is
  a no-op, so behavior is purely additive).
- Scoring v0 in Ruby mirrors the rs `CosineReranker` math (context
  neighbor vectors via the existing embedding provider seam) so the
  gem and native engines cannot drift apart; parity specs assert the
  same margins on fixture vectors.
- API surface: `check(..., real_word: false)` / server `/v1/check`
  opt-in body flag defaulting off — a precision-gated feature is
  opt-in until calibration earns default-on.
- FP budget is the product contract: thresholds come frozen from the
  models repo calibration (plan 15), never tuned in the gem.

## Consumers

rs plan 07 makes the same detection native (wasm/server paths). Plan
15's artifacts (confusion tables, thresholds) are the inputs; the
registry gains the resource type in a registry cut after both engine
plans land.
