# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Cache eviction** (`Kotoshu::Cache::EvictionPolicy` +
  `BaseCache#evict` + `kotoshu cache evict`). A pure value object
  decides which entries to evict (LRU by `cached_at`, oldest first)
  to fit a configured size cap; `BaseCache#evict` collects on-disk
  entries (one record per discovered `metadata.json`) and executes
  the plan. `--dry-run` returns the plan without touching disk. The
  cap defaults to `max_cache_size` (1 GB, `KOTOSHU_MAX_CACHE_SIZE`)
  and is now wired through `Configuration` instead of a hardcoded
  constant. Corrupt metadata (missing `cached_at`) sorts oldest so it
  is evicted first.
- **Audit log rotation** (`Kotoshu::Integrity::RotationPolicy`). When the
  current `audit.log` exceeds `audit_max_bytes` (default 10 MB,
  `KOTOSHU_AUDIT_MAX_BYTES`), the log rotates through `audit_rotations`
  historical files (default 5, `KOTOSHU_AUDIT_ROTATIONS`). Total on-disk
  footprint is bounded at `max_bytes * (rotations + 1)`. The rotation
  policy is a pure value object — `AuditLog#record` consults it on every
  write and executes the returned rename plan under an exclusive flock
  on a sibling lockfile (`audit.log.lock`) so concurrent writers cannot
  race the rename chain. `AuditLog#entries` now walks both the current
  log and all rotations, newest-first.
- **Shell completion** (`kotoshu completions bash|zsh|fish`). Emits a
  shell-specific completion script that completes top-level subcommands
  and dynamically completes language codes for `setup` / `fetch` by
  shelling out to `kotoshu completions languages`. README documents
  install paths for bash, zsh, and fish.

## [0.4.0] — 2026-06-29

Tier 2 release. Completes the Hunspell correctness work (morphological
rules, REP/phonet/ngram ranking, compound handling), migrates the entire
library from `require_relative` to Ruby `autoload`, and tightens the
cache interface alignment that 0.3.1 sketched.

### Added

- **Hunspell morphological correctness** (T2 Phases 2A–2D):
  - `FLAG long|num|utf-8` parsing and `AF` alias resolution.
  - `COMPOUNDRULE`, `CHECKCOMPOUNDPATTERN` (with empty-flag fix),
    `CIRCUMFIX` handling.
  - `ICONV`/`OCONV` `ConvTable` with stable sort — preserves Nepali
    `ZWNJ`/`ZWJ` ordering.
  - `KEEPCASE` suggestion flag with `CHECKSHARPS` exception, plus the
    German eszet rule (`ss` ↔ `SS`).
  - `REP` table, phonet ordering, ngram ranking wired end-to-end.
  - Edge cases: `IJ` digraph, `i58202` case preservation,
    `opentaal_forbiddenword2`, `breakdefault` `BREAK` pattern.
- **Hunspell Suggester** is now wired into the Hunspell dictionary; the
  default affix directives are honoured when generating suggestions.
- **`BaseCache#max_cache_size`** attribute (1 GB default) — the
  forward-looking hook for cache eviction work (see
  `TODO.impl/34-cache-eviction.md`).
- **`LanguageCache#language_path(lang, type)`** public helper; resource
  and metadata path resolution is now DRY'd through it.
- **`Kotoshu::Language` suika soft-load module** with specs — keeps
  tokenization lazy and optional.
- **Multi-language EditDistanceStrategy spec coverage** — pins
  per-language keyboard selection (QWERTZ/AZERTY/QWERTY/JCUKEN) and
  verifies German and French typo correction end-to-end. The previous
  `skip 'Multi-language support not yet implemented'` hook is removed;
  the strategy has been language-aware via `Keyboard::Registry` +
  `Cache::FrequencyCache` for several releases.

### Changed

- **Library-wide `autoload` migration.** Every `require_relative` (and
  in-library `require`) under `lib/kotoshu/` is replaced with a Ruby
  `autoload` declared in the immediate parent namespace's file. This
  fixes load-order races, makes the eager/opt-in split explicit, and
  matches the contributor guidance in `CLAUDE.md`. Behaviour is
  unchanged for callers who only `require "kotoshu"`, but extenders who
  reached past the public facade may need to update their load entry
  points.
- **`Embeddings` namespace consolidation.** All embedding classes are
  nested under `Kotoshu::Embeddings` (was scattered with several
  `require_relative` shims).
- **Grammar rules bundled in the gem.** English `rules.yaml` ships
  inside the gem package so a `gem install kotoshu` is self-contained
  for grammar checking without a separate download.
- **Plain-text edit distance is now case-insensitive**, matching the
  Hunspell backend's behaviour for `PlainText` dictionaries.

### Fixed

- **`Cli::CacheCommand` wired to the real `LanguageCache` API.** The
  previous implementation called nonexistent methods (`cache_status`,
  `get_frequency_data`, `get_language_info`, `purge_all`); `kotoshu cache`
  now correctly routes through `available?`, `cached_resources`,
  `clear_all`, `clean`, `stats`, `get_spelling`, `get_grammar`, and the
  standalone `Cache::FrequencyCache` for frequency downloads.
- **`Keyboard::Registry` lazy reload.** `clear` now marks
  `@languages_loaded = true` to prevent an infinite lazy-reload loop
  when the registry is reset at runtime.
- **German common-words YAML.** `data/common_words/de.yml` line 466 had
  `-ecke` (missing space after dash), a syntax error that prevented the
  file from loading and silently broke German strategy instantiation.
- **`Readers::AffReader` Hunspell edge cases** — encoding fallback for
  Latin-1 fixtures, `REP` table splitting, `MultiWord` dash variants,
  default affix directives honoured when the `.aff` file omits them.
- **RuboCop 3.x / plugins migration.** `rubocop-rspec` is bumped to
  3.x and the config uses the new plugins syntax; safe auto-corrections
  applied across `lib/` and `spec/` (`Layout/ExtraSpacing`,
  `Layout/EmptyLine`).
- **Cross-platform CI.** `bundle` is invoked via `Gem.ruby -S` for
  Windows compatibility; Ruby 4.0 compatibility fixes applied.

### Internal

- `TODO.impl/` planning documents (00–40) are the tiered execution
  plan. Tier 2 is complete; Tier 3 (`audit-log-rotation`,
  `cache-eviction`, `shell-completion`) and content-repo tasks
  (`onnx-vocab-json-generation`) remain deferred past 0.4.0.

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
