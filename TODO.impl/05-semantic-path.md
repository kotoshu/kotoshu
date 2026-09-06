# 05 — Semantic Path Productionization

## Goal

The ONNX/FastText semantic path is a first-class, always-available
dimension of analysis for every language that has an embedding model —
not an opt-in afterthought.

## Why

Today the semantic path is gated behind `ENV['KOTOSHU_REQUIRE_ONNX']`
(see `lib/kotoshu/models/onnx_model.rb` line 22). Without that env var,
the onnxruntime gem isn't loaded and semantic features silently
disappear. The hybrid model (`README.adoc` advertises "Hunspell
candidates + FastText reranking") is the recommended mode but isn't
wired as a default.

## Tasks

1. **Drop the env gate.** Require `onnxruntime` lazily on first
   `OnnxModel` instantiation, with a clear error if the gem isn't
   installed (`RuntimeError` with install instructions). Remove the
   `KOTOSHU_REQUIRE_ONNX` env var — it's an undocumented footgun.
2. **Make `onnxruntime` a hard runtime dependency** in
   `kotoshu.gemspec` (it already is, but the lazy require contradicts
   this). Verify `gem install kotoshu` pulls it in.
3. **Default to hybrid mode.** The README says hybrid is "recommended"
   but the code defaults to `hunspell` only (see
   `commands/check_command.rb` line 23). Make `:hybrid` the default;
   document when to choose pure `:hunspell` (speed) or pure
   `:fasttext` (semantic-only, no dictionary).
4. **Memory budget.** ONNX models are 200MB-4GB each. Only one model
   per language should be resident at a time. Wire
   `Embeddings::LruCache` so the `ResourceManager` owns the cache and
   evicts when memory pressure exceeds a configurable ceiling
   (`Configuration.max_embedding_memory_mb`, default 1024).
5. **Cold-start latency.** Loading a 4GB ONNX model takes seconds.
   Show a one-time progress message in the CLI; expose a `preload`
   method on `OnnxModel` so background warming is possible.
6. **Vocabulary coverage fallback.** If a word is OOV for the
   embedding model, fall back to subword FastText if available;
   otherwise skip semantic reranking for that word (don't crash).
7. **Hybrid scoring formula.** Document and tune the actual formula:
   `final_score = α·hunspell_distance_score + β·semantic_similarity +
   γ·frequency_bonus`. Make α/β/γ configurable per language; defaults
   per language live in the language module.
8. **Benchmark suite.** Add `spec/performance/semantic_bench.rb`:
   - Time to load model (baseline: < 1 s for the 114 MB models)
   - Time per 1000 suggestions with vs. without semantic rerank
     (baseline: ~1–2 ms/query inference, ~115 MB resident per language)
   - Memory ceiling under load
   Track these in `PERFORMANCE.md` and gate against regressions in CI.
9. **ONNX Runtime version compatibility.** README claims
   `onnxruntime 1.23.2+`. Verify across 1.22, 1.23, 1.24. Lock the gem
   version range in gemspec and document.

## Acceptance criteria

- `Kotoshu.suggest("helo", language: "en")` uses hybrid mode by
  default, no env var needed
- Loading two languages sequentially does not double memory (LRU
  evicts)
- `spec/performance/semantic_bench.rb` runs in CI and fails on >20%
  regression vs. baseline
- README's "hybrid" example works as documented
- `KOTOSHU_REQUIRE_ONNX` is removed from the codebase and from any
  docs that mention it

## Dependencies

- Blocks: `11-release`
- Blocked by: `03-dynamic-download` (model resolution), `09-integrity-security`
- Cross-repo: depends on `models-fasttext-onnx/TODO.impl/01-publish-all-models.md`

## Out of scope

- Training new FastText models (use upstream Facebook vectors)
- GPU acceleration (CPU onnxruntime is the v1 target)
- Quantization / INT8 (already 37x compressed vs. raw .vec — defer)

## Status

_Pending._
