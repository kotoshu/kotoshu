# 96 — kotoshu-server: semantic models over the HTTP API

## Context

The server is dictionary-only: `/v1/check`, `/v1/suggest`,
`/v1/detect` never load a model — `app.rb` has zero model surface.
The gem has supported semantic reranking since 0.7.0 (tiers,
registry, cascade). Every non-Ruby SDK user (python/js/go clients)
gets NO semantic quality through HTTP even though the engine under
the server can do it. Found in the wave-4 audit (2026-09-06).

## Design

- **Boot-time opt-in**: `KOTOSHU_SERVER_MODEL_LANGS` (space-separated,
  e.g. "en de it") + `KOTOSHU_SERVER_MODEL_TIER` (default `fluency`,
  the ecosystem default). On boot (the existing lazy-prewarm pattern —
  PR #1 detached warmup thread), set up spelling+model for the listed
  languages. No implicit downloads ever (the two-stage promise).
- **`/v1/check`** gains an optional `"model": true|false` request flag
  overriding the server default for that call; reranking rides the
  gem's existing check path (cascade decides when ONNX actually runs).
- **`/v1/languages`** reports `model: true|false` per language
  (from what is set up in the server's cache).
- **OpenAPI** (`openapi.yaml`) updated for the new field + response
  shape; README documents the env vars, memory expectations
  (~15 MB/language at fluency), and that the published 0.1.0 gem is
  broken (run from source until the 0.1.1 republish — owner gate).
- Specs against the real app (existing spec style — the repo has 9
  examples on real setup caches).

## Owner gates

None for source; the release itself remains the standing 0.1.1 gate.

## Status

**Pending.**
