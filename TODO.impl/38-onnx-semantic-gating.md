# 38 — ONNX Semantic Path Gating & Hardening

## Goal

Make the semantic path (ONNX FastText embeddings) a **first-class opt-in
feature** with a clear contract: when ONNX is absent, the traditional
path is unaffected; when ONNX is present, the semantic path is
testable, debuggable, and measurable.

## Why this is its own tier

The semantic path is the differentiator — it's the "semantic" in
"kotoshu is a semantic spell checker." But it depends on
`onnxruntime` (a native extension), a multi-megabyte model download per
language, and a non-trivial embedding pipeline. None of those can be
assumed present in CI or on a fresh `gem install`.

Right now the path is half-gated: specs that need ONNX fail noisily
rather than skipping; the runtime gating is correct but the test
gating are missing.

## Phase structure

### Phase A — Spec gating (the T1 deliverable)

This is also referenced from `TODO.impl/36-cleanup-regressions-0.3.1.md`
Phase A2; details here.

**Actions:**

1. Add `:onnx` to the `:integration`-tagged contexts in
   `spec/kotoshu/suggestions/strategies/semantic_strategy_spec.rb`
   (currently tagged `:integration` only — repurpose to `:onnx` since
   the file is the sole user).
2. Update `spec/spec_helper.rb`:
   ```ruby
   config.filter_run_excluding :onnx unless ENV.fetch("ONNX_TESTS", nil)
   ```
3. Document `ONNX_TESTS=1` in `CLAUDE.md` Notes section, mirroring the
   `NETWORK_TESTS=1` pattern.
4. Add a "smoke" spec (always-run, no `:onnx` tag) that asserts
   `Kotoshu::Models::OnnxModel::ONNX_LOADED` matches
   `Gem::Specification.find_all_by_name("onnxruntime").any?`. This
   catches the silent regression where the soft-require path breaks.

**Acceptance:**

- `bundle exec rspec` (default) → 0 ONNX-related failures.
- `ONNX_TESTS=1 bundle exec rspec spec/kotoshu/suggestions/strategies/semantic_strategy_spec.rb`
  → either all green (if onnxruntime installed + model cached) or all
  skipped with a clear "model not cached; run `kotoshu setup :en --model`"
  message.

### Phase B — Runtime gating hardening

**Audit each entry point into the semantic path:**

1. `Kotoshu::Analyzers::SemanticAnalyzer` — already raises
   `Models::OnnxModel::OnnxUnavailable`. Verify the message is
   actionable.
2. `Suggestions::Strategies::SemanticStrategy#generate` — returns an
   empty `SuggestionSet` when ONNX is unavailable. This is silent;
   consider logging at debug level.
3. `Kotoshu.correct?` / `Kotoshu.suggest` / `Kotoshu.check` — these
   should *never* hit the semantic path unless explicitly requested
   (e.g. via `Kotoshu.suggest(word, semantic: true)`). Verify.
4. `KOTOSHU_NO_ONNX=1` is documented; verify it short-circuits all
   semantic entry points.

**Acceptance:** with `onnxruntime` *installed* but
`KOTOSHU_NO_ONNX=1` set, `bundle exec rspec --tag ~network --tag ~onnx`
passes. With `onnxruntime` *uninstalled*, same suite passes.

### Phase C — Model cache correctness

The semantic path depends on `Cache::ModelCache` finding a model file
under `~/.cache/kotoshu/models/{lang}/`. Issues to address:

1. **Manifest validation.** `kotoshu/models-fasttext-onnx` ships a
   `manifest.json` (18 entries per `kotoshu-content-repos-state.md`
   memory). Verify `ModelCache` reads the manifest, not a glob, and
   rejects unknown shapes.
2. **Version pinning.** Each manifest entry should have a content hash
   or version; verify the cache checks it.
3. **Stale-model recovery.** If the model file is truncated or the
   onnxruntime session can't deserialize, the error message should
   point to `kotoshu cache download :en --model` (or equivalent).

**Acceptance:** deliberately corrupt a cached model file; the next
`Kotoshu.suggest(word, semantic: true)` raises a clear, actionable
error and points the user to the cache subcommand.

### Phase D — Vocabulary / embedding pipeline tests

The `Embeddings::*` namespace (vocabulary, similarity engine, search,
LRU cache) is undertested. Add specs for:

1. `Embeddings::Vocabulary` — token → id, id → token round-trip; OOV
   behavior; boundary indices.
2. `Embeddings::SimilarityEngine` — cosine similarity of orthogonal
   vs identical vectors; dimension mismatch handling.
3. `Embeddings::LruCache` — eviction at capacity; hit/miss accounting.

**These specs do not require ONNX** — they test the math, not the
runtime. They should be in the always-run suite.

**Acceptance:** the three classes above have direct unit specs (no
`:onnx` tag), all green in default `bundle exec rspec`.

### Phase E — End-to-end semantic smoke test

A single `:onnx`-tagged spec that:

1. Resolves the English model from cache (skip if missing).
2. Builds a `SemanticAnalyzer` for English.
3. Asserts that `analyze("their")` vs `analyze("there")` returns
   distinguishable contexts.
4. Asserts that `Kotoshu.suggest("helo", semantic: true)` returns
   "hello" in the top 5.

This is the "does the semantic path actually work end-to-end" guard.

**Acceptance:** spec passes when ONNX is available; skips with a clear
message otherwise.

## Cross-cutting: OCP/MECE audit

While doing the above, audit the embeddings namespace for:

- **OCP violations:** places where adding a new model type (e.g.
  Word2Vec, GloVe) requires editing a switch instead of registering.
- **MECE violations:** overlap between `Embeddings::SimilarityEngine`
  and `Embeddings::SimilaritySearch` — if they have overlapping
  responsibilities, consolidate or split cleanly.
- **DRY:** the embedding-pipeline code is the prime suspect for
  copy-paste between FastText and ONNX paths.

Document findings; address in T3 if scope creep risks the release.

## Acceptance criteria

- Default `bundle exec rspec` → 0 ONNX-related failures, 0 ONNX-related
  skips leaking into the non-`:onnx` suite.
- `ONNX_TESTS=1 bundle exec rspec --tag onnx` → all green (with model
  cached) or all gracefully skipped (without).
- `KOTOSHU_NO_ONNX=1 bundle exec rspec` → identical pass rate to the
  default run.
- Semantic path is documented end-to-end in a single place (probably
  `docs/semantic-path.md`).

## Dependencies

- **Blocked by:** nothing.
- **Blocks:** `TODO.impl/39-tier3-and-beyond.md` (the grammar / CJK
  work uses the embedding pipeline; the gating must be solid first).

## Status (re-audited 2026-09-03)

Done long ago: Phase A gating (`spec_helper.rb` `:onnx` exclusion,
`ONNX_TESTS=1` opt-in documented in CLAUDE.md), Phase D unit specs
(`embeddings/vocabulary_spec`, `similarity_engine_spec`, `lru_cache_spec`,
`models/models_spec`), Phase E e2e spec (`spec/kotoshu/semantic_e2e_spec.rb`,
tagged `:onnx` with skip guards).

Verified today:

- Phase B: `KOTOSHU_NO_ONNX=1 bundle exec rspec --tag ~network --tag ~onnx`
  → 3285 examples, 0 failures (one extra skip: the new load-failure spec
  correctly skips when the runtime is off). `SemanticStrategy` empty-return
  still only warns at construction (`warn … if $VERBOSE`); there is no
  debug-log infrastructure in the gem — left as-is (building one is out of
  scope for this residue pass).

Fixed today (branch `fix/plan36-38-residue`):

- **vocab.json format drift** (the live 5 failures in
  `semantic_strategy_spec`): the models repo / `fasttext_to_onnx.py` ship
  vocab.json as `{"vocab_size", "word_to_idx"}`; `Embeddings::Vocabulary`
  and `Models::OnnxModel.from_file` only parsed flat maps, so
  `SemanticStrategy.new(language_code: "en")` crashed in
  `Vocabulary#initialize` (`TypeError` via `Hash#<`). Both loaders now
  share `Vocabulary.word_to_index_from_document` (flat, wrapped, and array
  shapes); `Vocabulary#initialize` raises a clear ArgumentError for
  non-Integer index values instead of the cryptic TypeError.
- **LFS pointer corruption** (Phase C root cause):
  `raw.githubusercontent.com` serves 134-byte LFS pointer stubs for the
  LFS-tracked `*.onnx`; the legacy full-tier download cached a stub and
  recorded the stub's own sha256, so checksum verification passed forever
  and the runtime died with a raw `OnnxRuntime::Error: Protobuf parsing
  failed`. Fixes: `SourceRegistry` fetches `:model` from
  `media.githubusercontent.com/media` (LFS host; custom mirrors untouched),
  `ModelCache` refuses pointer stubs at download time and at
  `verify_cached_integrity!` (purges stub + metadata, raises an error
  pointing at `kotoshu cache download :{lang} --model`), and
  `Embeddings::OnnxRuntimeModel#load!` wraps session-creation failures in
  the same actionable `Kotoshu::Error`.
- **`Models::OnnxModel` session rot** (previously masked by the vocab
  crash): `OnnxRuntime::Session` (nonexistent class) →
  `OnnxRuntime::InferenceSession` with graph-detected IO names
  (`word_index`/`embedding`); tensor I/O now uses real values instead of
  `pack('q<')`/`unpack('e*')` byte surgery; batching executes sequential
  single lookups (the converted graph's input is fixed shape [1]).
- **Spec drift**: strategy config examples no longer construct against the
  developer's real `en` cache (use `xx`, per the file's own convention —
  construction could otherwise trigger a 120MB download mid-spec);
  identical-word similarity compared with float tolerance; removed the
  stale `#embedding_for` describe (that API lives on the model, not the
  strategy). New direct specs: `models/onnx_model_spec` (both vocab shapes),
  `embeddings/onnx_runtime_model_spec` (actionable corrupt-model error).

`ONNX_TESTS=1 bundle exec rspec` on the semantic specs: 32 examples,
0 failures against the real cached English model.

Remains (noted, not blocking): `Embeddings::OnnxRuntimeModel`'s
`run_batch_inference` feeds >1 indices to a fixed-shape-[1] graph, so
multi-index `get_embeddings` / `preload_embeddings!` fail at runtime; the
live single-lookup path is unaffected. Belongs with the tiered-model work
(plans 39/67).
