# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] — 2026-06-28

Bug-fix release. Closes the regressions introduced by the 0.3.0
lutaml-model migration and tightens up spec gating so the default suite
is green on the non-network, non-ONNX subset.

### Fixed

- `WordResult#suggestions` is `Array<Suggestion>` after the lutaml
  migration; the integration spec now reads it as
  `suggestions.map(&:word)` instead of the removed `SuggestionSet#words`.
- `WordResult#to_h` was removed by lutaml; the integration spec now uses
  the framework-supplied `to_hash`.
- `Readers::AffReader#detect_encoding` now handles a nil path so the
  reader can be constructed from an in-memory `StringReader` (used by
  the unit tests and by programmatic callers that build affix data
  without a file on disk).
- `Embeddings::SimilaritySearch` is now eagerly loaded alongside the
  rest of the embeddings namespace; previously the constant was
  uninitialized when `SemanticStrategy` tried to use it.
- `Embeddings::Vocabulary.from_cache` is implemented (was missing). It
  resolves the `vocab.json` sibling of the cached ONNX model and
  returns nil when the model or vocab is unavailable, so callers can
  degrade gracefully.
- `Embeddings::OnnxRuntimeModel.from_cache` now accepts the `cache:`
  keyword (matching `Vocabulary.from_cache` and
  `SimilaritySearch.from_cache`); the previous positional signature
  silently swallowed the cache as a Hash.
- `Suggestions::Strategies::SemanticStrategy` now surfaces its named
  constructor kwargs (`min_semantic_similarity`,
  `semantic_boost_weight`, `max_context_window`) through `get_config`,
  so the strategy's configurable knobs are queryable the same way as
  the base strategy's `**config` bag.

### Changed

- `spec/spec_helper.rb` excludes `:onnx`-tagged examples unless
  `ONNX_TESTS=1` is set, mirroring the existing `:network` and `:slow`
  opt-in pattern. `spec/kotoshu/suggestions/strategies/semantic_strategy_spec.rb`
  is the sole consumer; its `:integration` tags are now `:onnx`.
- The SymSpell benchmark spec and the edit-distance / symspell
  performance describe blocks are tagged `:slow`, removing
  environment-dependent timing flakes from the default run.
- Arabic language detection is marked `pending` with a pointer to
  `TODO.impl/30-language-auto-detection.md` (FastText LID missing the
  Arabic vector).
- `edit_distance_strategy_spec` now uses the `from_source?` predicate
  instead of asserting `source == :edit_distance`, matching the
  lutaml-era contract that `Suggestion#source` is a string.

### Internal

- Added `TODO.impl/36-cleanup-regressions-0.3.1.md` (this release),
  `TODO.impl/37-hunspell-correctness-tier2.md`,
  `TODO.impl/38-onnx-semantic-gating.md`, and
  `TODO.impl/39-tier3-and-beyond.md` as the tiered execution plan.

## [0.3.0] — 2026-06-27

The two-stage release. Resources are now downloaded explicitly via
`Kotoshu.setup(:en)`; the hot path (`correct?`, `suggest`, `check`) reads
only from cache and raises a typed error when a language is missing instead
of triggering a network download. The CLI adds `setup`, `status`, language
auto-detection, SARIF/JSON output, and an interactive auto-setup prompt.
`onnxruntime` is now a soft dependency, so `gem install kotoshu` succeeds on
hosts that can't load native ONNX runtime.

### Added

- **Two-stage resource model** (`Kotoshu::ResourceManager`):
  `Kotoshu.setup(:en, want: %i[spelling frequency model])` writes into the
  cache; `Kotoshu::ResourceManager.resolve(language:, want:)` is instant and
  cache-only, raising `ResourceNotSetupError` on miss. `Kotoshu.setup?` is
  the predicate for "is this language already cached?". The library never
  triggers a surprise download; the CLI prompts the user via `AutoSetup`.
- **`SourceRegistry`** — single source of truth for the three content repos'
  URLs and per-repo pins. `kotoshu/dictionaries` is pinned to the `v1`
  branch; `frequency-list-kelly` and `models-fasttext-onnx` are on `main`.
  Override at runtime via `KOTOSHU_REPOS_BASE_URL`, `KOTOSHU_DICTIONARIES_PIN`,
  `KOTOSHU_FREQUENCY_PIN`, `KOTOSHU_MODELS_PIN`.
- **XDG Base Directory layout** (`Kotoshu::Paths`): dictionaries, frequency
  lists, ONNX models under `$XDG_CACHE_HOME/kotoshu/`; personal dictionary
  and `kotoshu.cfg` under `$XDG_CONFIG_HOME/kotoshu/`; audit log under
  `$XDG_DATA_HOME/kotoshu/audit.log`. Override per-axis with
  `KOTOSHU_CACHE_PATH`, `KOTOSHU_CONFIG_PATH`, `KOTOSHU_DATA_PATH`.
- **Integrity verification** — `Kotoshu::Integrity::Manifest` (SHA-256) is
  fetched per content repo and matched against every download. Mismatches
  raise `Kotoshu::IntegrityError`. Outcomes (verified / unverified / mismatch)
  are written to the audit log. Missing manifests degrade gracefully.
- **CLI `setup` command** — `kotoshu setup LANG [--force] [--no-frequency]
  [--no-model]` writes the requested resources into the cache with progress
  reporting.
- **CLI `status` command** — `kotoshu status [--json]` summarises installed
  resources, sizes, mtimes, and ONNX runtime availability.
- **CLI `check --language auto`** — auto-detects document language via
  FastText LID; falls back to the configured default language when detection
  is unavailable or the detected language is not set up.
- **CLI `check --format json|sarif`** — machine-readable output. SARIF
  follows v2.1.0 with `kotoshu/spelling` rule id, JSON exposes
  `success`/`wordCount`/`errorCount`/`uniqueErrorCount`/`errors`/`source`.
- **CLI auto-setup prompt** — when the hot path raises
  `ResourceNotSetupError` in an interactive session, the user is prompted to
  run setup now and the original command is retried on success. Non-TTY,
  offline (`--offline`), and `--no-prompt` invocations skip the prompt and
  surface the error as before.
- **Download progress reporting** (`Kotoshu::Cli::ProgressReporter`) — TTY
  mode renders a determinate/indeterminate progress bar; non-TTY mode prints
  a periodic line every 10 MiB. `Kotoshu.configuration.download_reporter=`
  exposes the reporter for programmatic use.
- **End-to-end smoke spec** (`spec/integration/end_to_end_spec.rb`) covers
  install → setup → `correct?` → `suggest.to_words` → `check` →
  `setup?` predicate → `ResourceNotSetupError` → idempotent re-setup.
  Tagged `:network`, opted into via `NETWORK_TESTS=1`.
- **CLI format spec** (`spec/kotoshu/cli/check_format_spec.rb`) shells out to
  the real `kotoshu` CLI and asserts JSON / SARIF structure and exit codes.

### Changed

- **`onnxruntime` is a soft dependency.** Removed from `kotoshu.gemspec`.
  `Kotoshu::Models::OnnxModel` soft-requires it at load time and exposes
  `ONNX_LOADED`. When false, semantic methods raise
  `Kotoshu::Models::OnnxModel::OnnxUnavailable` with a caller-friendly
  message. `KOTOSHU_NO_ONNX=1` forces semantic off even when the gem is
  present. The traditional spell-checking path never touches `onnxruntime`.
- **Loading strategy** — `lib/kotoshu.rb` eagerly loads only the facade
  dependencies; heavier or optional pieces (ONNX models, interactive CLI,
  caches, language detection) are wired through Ruby `autoload` registered
  in their immediate parent namespace.
- **Public API** — `suggest` returns a `SuggestionSet`; call `.to_words` for
  an `Array<String>`. `Kotoshu.check` returns a `DocumentResult`; iterate
  `errors` for `WordResult` instances with `word`, `position`, `line`,
  `column`, `suggestions`.
- **README quickstart** — reflects the two-stage API; documents XDG paths;
  marks `onnxruntime` as optional.

### Fixed

- `gem install kotoshu` no longer requires `onnxruntime` or its native
  toolchain.
- Resource resolution no longer triggers downloads from inside the hot path.
- Per-repo pins are honoured — the `v1` branch of `kotoshu/dictionaries` is
  fetched instead of `main`.

### Known limitations (carried from 0.1.0, scope reduced)

- **Hunspell correctness**: compound rules, circumfix, ICONV/OCONV, German ß,
  Turkish dotless-i remain partial. See `TODO.impl/01-hunspell-correctness.md`.
- **CJK and RTL**: tokenizer, normalizer, and keyboard layouts exist for
  supported languages; full CJK/RTL support deferred past 0.3.
  See `TODO.impl/06-cjk-support.md` and `TODO.impl/07-rtl-support.md`.
- **Grammar rules**: the rule engine exists; no rule packs are shipped.
  See `TODO.impl/08-grammar-engine.md`.
- **Audit log rotation, cache eviction policy, and shell completion** are
  deferred past 0.3 (T3 TODOs).

### Internal

- 9 logical commits on `release-0.3` cover the T1 (architectural) and T2
  (user-facing) work for this release.
- `SourceRegistry`, `Paths`, `ResourceManager`, `ResourceBundle`,
  `SetupResult`, `Integrity::Manifest`, `Integrity::AuditLog`,
  `Cli::AutoSetup`, `Cli::StatusReport`, `Cli::LanguageResolver`,
  `Cli::ProgressReporter` are new model-driven types.
- 73 new specs added (source_registry, end_to_end, check_format,
  progress_reporter, language_resolver, status_report, auto_setup).

### Contributors

- Ribose Inc.

## [0.1.0] — 2026-06-25

First public release. Kotoshu is a pure-Ruby spellchecker that combines a
Ruby port of the Hunspell algorithm with optional FastText ONNX embeddings
for semantic reranking. This release establishes the public Ruby API, the
basic CLI, and the cache layer.

### Working

- **Ruby API**: `Kotoshu.correct?`, `Kotoshu.suggest`, `Kotoshu.check`,
  `Kotoshu.check_file`, `Kotoshu.detect_language`
- **CLI**: `kotoshu check TARGET`, `kotoshu dict SUBCOMMAND`, `kotoshu cache
  SUBCOMMAND`, `kotoshu version`
- **Dictionary backends**: Hunspell (`.aff`/`.dic`), CSpell, UnixWords
  (`/usr/share/dict/words`), PlainText, Custom
- **Suggestion strategies**: edit distance, phonetic (Phonet), keyboard
  proximity, n-gram, symspell, composite pipeline
- **Configuration**: `Kotoshu.configure`, CLI > ENV (`KOTOSHU_*`) >
  programmatic > defaults via `Configuration::Resolver`
- **Cache layer**: `LanguageCache`, `FrequencyCache`, `ModelCache` with TTLs
  and download from `kotoshu/dictionaries`, `kotoshu/frequency-list-kelly`,
  `kotoshu/models-fasttext-onnx`
- **Language detection**: FastText LID, 127 languages
- **Documents**: Plain text, Markdown (Kramdown), AsciiDoc (Asciidoctor)
- **Test suite**: 803 of 866 examples passing (92.7%), 6 pending

### Known limitations (not blocking 0.1)

- **Hunspell correctness**: compound rules, circumfix, ICONV/OCONV, German
  ß, Turkish dotless-i are not fully implemented. Single-word lookup and
  basic affixes work. See `TODO.impl/01-hunspell-correctness.md`.
- **CLI surface**: `--interactive`, `--format sarif|json|yaml|csv`,
  `--model fasttext|hybrid`, `--language auto` exist in
  `lib/kotoshu/commands/check_command.rb` but are not wired through
  `exe/kotoshu`. See `TODO.impl/02-cli-unification.md`.
- **Semantic path**: gated behind `ENV['KOTOSHU_REQUIRE_ONNX']` because
  `onnxruntime` loads eagerly otherwise. Hybrid mode is not the default.
  See `TODO.impl/05-semantic-path.md`.
- **Dynamic resolution**: the three caches exist independently; there is
  no unified `ResourceManager` that takes arbitrary text and yields the
  full resource bundle. See `TODO.impl/03-dynamic-download.md`.
- **Languages**: code is wired for English by default. The
  `dictionaries` repo has 98 language directories but the gem's
  `lib/kotoshu/languages/` has only 7 modules (de, en, es, fr, ja, pt,
  ru). See `TODO.impl/04-language-modules.md`.
- **CJK, RTL**: not implemented. See `TODO.impl/06-cjk-support.md`
  and `TODO.impl/07-rtl-support.md`.
- **Grammar rules**: the rule engine exists; no rule packs are shipped.
  See `TODO.impl/08-grammar-engine.md`.
- **Integrity verification**: downloaded resources are not currently
  checksummed. See `TODO.impl/09-integrity-security.md`.

### Internal

- 12 plans under `TODO.impl/` define the path to 1.0
- Architecture documentation consolidated under `docs/`

### Contributors

- Ribose Inc.
