# Plan 131 — Productize the hybrid: C-retrieve + fastText-rescore in the engines

Status: proposed (the decision evidence is complete; plan 128 verdict SHIP)
Depends on: plan 128 (verdict + artifacts), plan 113 (packs — the
delivery vehicle), registry v1.6.0 (typo-biencoder assets already opt-in)

## What ships

The hybrid becomes the opt-in "typo retrieval" layer, the same shape
as the semantic tier: per-language int8 C-matrix (25.8 MB) + the char
bi-encoder (0.48 MB) fetched from the registry, C-retrieve top-20 over
the vocabulary, fastText-rescore of the candidates, merged into the
suggestion pipeline ahead of frequency ranking.

## Surfaces

- kotoshu-rs: char-bi-encoder ONNX inference (the pure-Rust ONNX
  reader already exists for the tiers), the retrieval+rescore path,
  wasm surface (`loadTypo` + `typoSuggest`), KPK1 pack extension (the
  C-matrix rides the pack for pack languages).
- gem: native-ext accelerated path where present; the merge into
  Suggestions::Pipeline as a strategy (OCP: a new strategy class, no
  pipeline surgery).
- Conformance: new vectors for the hybrid path are NOT frozen
  initially (it is opt-in, tier-like, gated by eval not conformance —
  the tier precedent).
- Registry: promote the typo-biencoder entries from opt-in to exposed;
  server/playground/worker flips follow the semantic-tier pattern.

## Gates (pre-declared)

- The frozen real components + synth corpora re-run against the
  SHIPPED engines must reproduce the PR-34 numbers within noise.
- Latency: per-suggest budget ≤ 10 ms amortized (the plan-112 gates
  tighten for the shipped path).
- Degrades nowhere vs dictionary-only when disabled; zero behavior
  change at default settings.

## Non-goals

- No retraining; the v2 artifacts are frozen (probe_hit5 0.410).
- No default-on: opt-in per language, like the semantic tier.
