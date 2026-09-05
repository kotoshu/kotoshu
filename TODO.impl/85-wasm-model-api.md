# 85 — Browser semantic reranking: wasm model API

## Context

The playground is honestly dictionary-only for two reasons found in
wave 1: GitHub release assets send no CORS headers, and the wasm
surface exposes no model API. The first is a distribution problem;
the second is the real gap — this plan closes both.

## Track A — CORS spike (decides the distribution path)

Check `Access-Control-Allow-Origin` on: the media-host mirror URLs in
the registry, the models repo's raw.githubusercontent paths, and the
registry.json itself (which the browser must read to discover URLs).
Outcomes:
- Media host serves ACAO → use registry mirror URLs directly.
- Nothing serves ACAO → tier artifacts move into the jsDelivr-servable
  git tree (tiers are LFS-free and ~3-15 MB; jsDelivr gh caps at
  20 MB) via a registry "browser_url" field — additive schema, old
  consumers unaffected.
Record the verdict + evidence in this file.

## Track B — wasm model API

Expose on `@kotoshu/wasm` (wasm-bindgen surface, kotoshu-wasm crate):
- `createModelDictionary`-adjacent: `loadModel(bytes, vocabBytes)`
  parsing the int8 tier (quantized matrix + vocab) into memory.
- `rerank(word, context) -> f32 score` (dot-product against the
  quantized embeddings, dequantized on the fly) — enough to drive the
  same reranking the gem does. Pure Rust, NO ort in the wasm build
  (load-dynamic cannot work in a browser); the int8 tiers exist
  precisely so this is cheap.
- Memory discipline: document peak memory (vocab 10k-50k × int8 ×
  dim ≈ 3-15 MB) and free on `drop`.
- Node smoke in CI exercises load + rerank against a real mini-tier
  fixture (checked-in, small) — the same pattern as the dictionary
  smoke.

## Track C — release readiness (owner-gated)

npm version 0.2.0 candidate: PR + CI only. Publishing @kotoshu/wasm
is the owner's version call (tag `@kotoshu/wasm-v*` publishes keyless
once decided). Playground wiring happens after the API ships, as a
site follow-up.

## Status

**Pending.**
