# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Kotoshu Is

Kotoshu 「言修」 is a **semantic** spell checker for Ruby. It pairs a traditional
dictionary/affix backend (Hunspell-style) with ONNX-converted FastText word
embeddings for context-aware suggestions. The README.adoc is the authoritative
user-facing description; this file is the contributor-facing map.

Key dependencies (`kotoshu.gemspec`): `thor` (CLI), `suika` (tokenizer),
`onnxruntime` (semantic inference). Ruby 3.1+.

## Development Commands

```bash
bundle exec rspec                       # Run the full test suite
bundle exec rspec spec/path/to_spec.rb  # Run one file
bundle exec rspec -e "matches a word"   # Run examples matching a name
bundle exec rspec --only-failures       # Rerun just failing examples (uses .rspec_status)

NETWORK_TESTS=1 bundle exec rspec       # Opt INTO tests that download dictionaries
ONNX_TESTS=1 bundle exec rspec          # Opt INTO tests that need onnxruntime + cached models
SLOW_TESTS=1 bundle exec rspec          # Opt INTO benchmarks and full-dictionary sweeps
bundle exec rubocop                     # Lint
bundle exec rubocop -A                  # Lint with safe auto-fix
bundle exec rake                        # default task = spec + rubocop

bundle exec bin/console                 # IRB with Kotoshu loaded
bundle exec exe/kotoshu check FILE      # Run the CLI locally
gem build kotoshu.gemspec && gem install kotoshu-*.gem
```

Notes that aren't obvious from the Rakefile:
- `spec/spec_helper.rb` excludes anything tagged `:network` unless `NETWORK_TESTS=1` is set — those specs download dictionaries from GitHub and are slow/flaky.
- `spec/spec_helper.rb` excludes anything tagged `:onnx` unless `ONNX_TESTS=1` is set — those specs need `onnxruntime` installed **and** the language model cached via `kotoshu setup :en --model`.
- `spec/spec_helper.rb` excludes anything tagged `:slow` unless `SLOW_TESTS=1` is set — those are timing-sensitive benchmarks and full-dictionary sweeps.
- SimpleCov runs on every `rspec` invocation (configured in `spec_helper.rb`).
- `spec/spylls_test_helper.rb` is mixed into every spec. It ports Hunspell's reference test fixtures from [Splylls](https://github.com/neolithos/spylls) (the Python Hunspell port); many specs assert behavior against those fixtures.

## Architecture

Kotoshu has **two parallel checking paths** that share infrastructure:

1. **Traditional path** — `Kotoshu::Spellchecker` (facade) → `Suggestions::Generator` → pluggable `Dictionary::*` backends + `Suggestions::Strategies::*` algorithms. This is what `Kotoshu.correct?` / `Kotoshu.suggest` / `Kotoshu.check` use.
2. **Semantic path** — `Analyzers::SemanticAnalyzer` driven by an `Models::EmbeddingModel` (`FastTextModel` or `OnnxModel`). Used for context-aware reranking and OOV handling. This path is **opt-in** and only loads when needed.

### Layer map

```
exe/kotoshu ─► lib/kotoshu/cli.rb (Kotoshu::Cli::Cli < Thor)
                    subcommands: check, dict (DictCommand), cache (CacheCommand)
                    helpers: cli/interactive_reviewer, cli/batch_reporter,
                             cli/navigation_manager, cli/display_formatter

Kotoshu module (lib/kotoshu.rb) ─► public facade methods
                    .correct? .suggest .check .check_file .detect_language ...
                    all delegate to a singleton Spellchecker

Spellchecker ─► Configuration ─► Dictionary::Repository ─► Dictionary::*
                                              │
                                              └─► Suggestions::Generator
                                                       └─► Strategies::CompositeStrategy
                                                                (edit_distance, phonetic,
                                                                 keyboard_proximity, ngram,
                                                                 symspell, semantic)

SemanticAnalyzer ─► Models::OnnxModel | Models::FastTextModel
                       └─► Embeddings::* (vocabulary, similarity search, LRU cache)
```

### Loading strategy

`lib/kotoshu.rb` eagerly `require_relative`s the traditional path (core models, dictionaries, strategies, configuration, spellchecker) and `autoload`s the heavier / optional pieces (ONNX models, documents, interactive CLI, caches, language detection, debug/metrics). When adding a new top-level component, follow the existing split: eager-load only what the facade needs at boot; autoload the rest.

**ONNX is a soft dependency.** `onnxruntime` is NOT in `kotoshu.gemspec` — `gem install kotoshu` succeeds without it. `Models::OnnxModel` soft-requires it at load time and exposes `ONNX_LOADED` (true/false). When false, semantic methods raise `Models::OnnxModel::OnnxUnavailable` with a caller-friendly message. `KOTOSHU_NO_ONNX=1` forces semantic off even when the gem is present. The traditional spell-checking path never touches onnxruntime.

### Resource lifecycle — two-stage model

Resources (dictionaries, frequency lists, ONNX models) flow through a strict two-stage API in `ResourceManager`:

1. **Setup** (`Kotoshu.setup(:en, want: %i[spelling frequency model])`, or `Kotoshu.setup(:en, aff:, dic:)` / `from:` for local sources). Slow, network-required, explicit. Writes into the cache.
2. **Resolve** (`Kotoshu::ResourceManager.resolve(language:, want:)`). Instant, cache-only, raises `ResourceNotSetupError` on miss.

The hot path (`Kotoshu.correct?`, `.check`, `.suggest`, `.spellchecker_for`) calls `resolve` and lets the error propagate — **setup is never implicit**. This is intentional: users on metered networks or air-gapped hosts must not get a surprise download. `Kotoshu.setup?(:en, resource: :spelling|:frequency|:model)` is the predicate for "is this already in cache?".

`ResourceBundle` (the resolve result) carries `dictionary`, `frequency`, `model`, and `rules`. `SetupResult` (the setup result) reports per-resource status (`:downloaded | :local | :cached | :unavailable`).

### Paths — XDG Base Directory

All on-disk locations are resolved through `Kotoshu::Paths`, which honors `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_LOCAL_HOME` and the override envs `KOTOSHU_CACHE_PATH`, `KOTOSHU_CONFIG_PATH`, `KOTOSHU_DATA_PATH`. Defaults:

| Concern | Default path |
|---|---|
| Language dictionaries, frequency lists, ONNX models | `~/.cache/kotoshu/` |
| Personal dictionary, kotoshu.cfg | `~/.config/kotoshu/` |
| Audit log | `~/.local/share/kotoshu/audit.log` |

### Resource caching

Three caches under `~/.cache/kotoshu/` (see `CACHE_ARCHITECTURE.md` for detail, README.adoc for the user-facing version):

| Cache | Path | Source | TTL |
|---|---|---|---|
| `Cache::LanguageCache` | `~/.cache/kotoshu/languages/{code}/spelling/` | `github.com/kotoshu/dictionaries` | 7 days |
| `Cache::FrequencyCache` | `~/.cache/kotoshu/frequency-lists/{code}/` | `github.com/kotoshu/frequency-list-kelly` | 7 days |
| `Cache::ModelCache` | `~/.cache/kotoshu/models/{code}/...` | `github.com/kotoshu/models-fasttext-onnx` (FastText `.vec` → ONNX converted upstream) | 30 days |

`FrequencyCache` feeds `frequency_bonus` in `Suggestions::Strategies::EditDistanceStrategy` — high-frequency words get a ranking boost. The `kotoshu cache` subcommand exposes list/status/download/info/purge/clean operations.

### Configuration

`Configuration` (singleton via `.instance`) is built from a `SCHEMA` hash that declares each option's ENV var, default, type, and description. The `Configuration::Resolver` enforces the priority chain: **CLI flags > ENV (`KOTOSHU_*`) > programmatic > defaults**. When adding a config option, add it to `SCHEMA` (and probably `DEFAULTS`) rather than sprinkling `attr_accessor`s — that's how it picks up ENV support automatically.

`dictionary_type` selects the backend: `:unix_words | :plain_text | :custom | :hunspell | :cspell`. The dictionary is lazy-loaded through `Configuration#dictionary` (cached on the instance; call `reset_dictionary` to reload).

### Language support

Full features (dictionary + affixes + FastText + ONNX + keyboard layout): `de, en, es, fr, pt, ru`.
Kelly frequency only: `ar, zh, el, it, no, sv` (and `ru`).
`Language::Identifier` does automatic detection (FastText LID model, 127 languages). Per-language behavior (tokenizer, normalizer) lives in `languages/{code}/language.rb` and `language/tokenizer/*`. Keyboard layouts (`keyboard/layouts/*`) feed `KeyboardProximityStrategy`.

### Suggestion strategies

`Suggestions::Generator::DEFAULT_ALGORITHMS` = `[EditDistanceStrategy, PhoneticStrategy, KeyboardProximityStrategy, NgramStrategy]`, composed via `Strategies::CompositeStrategy`. Also available: `SymspellStrategy`, `SemanticStrategy`. Register new algorithms via `Kotoshu.register_suggestion_algorithm(:name, Klass)` (uses `BaseStrategy.register_type`).

## Code Layout (lib/kotoshu/)

| Path | Responsibility |
|---|---|
| `kotoshu.rb` | Public facade + eager/autoload wiring |
| `spellchecker.rb`, `spellchecker/parallel_checker.rb` | Traditional check facade |
| `paths.rb` | XDG path resolution (cache, config, data, audit log, personal dict) |
| `resource_manager.rb`, `resource_bundle.rb` | Two-stage setup/resolve flow + result structs |
| `configuration.rb`, `configuration/{builder,resolver}.rb` | Config + priority resolution |
| `core/` | Domain models (`Word`, `AffixRule`, `result/*`), `IndexedDictionary`, `Trie/*`, `exceptions` |
| `dictionary/` | Backends: `base`, `hunspell`, `cspell`, `unix_words`, `plain_text`, `custom`, `unified`, `repository` |
| `readers/` | Parsers for Hunspell `.aff` / `.dic` (aff_data, aff_reader, dic_reader, condition_checker, lookup_builder) |
| `suggestions/` | `generator`, `context`, `suggestion{,_set}`, `pipeline`, `strategies/*` |
| `algorithms/` | Lower-level Hunspell-style suggestion primitives (ported from Spylls): `ngram_suggest`, `phonet_suggest`, `suggest`, `lookup`, `permutations`, `capitalization` |
| `analyzers/` | `semantic_analyzer` — the embedding-based checker |
| `models/` | `embedding_model` (abstract), `fasttext_model`, `onnx_model`, `word_embedding`, `nearest_neighbor`, `semantic_error`, `context`, `suggestion` |
| `embeddings/` | ONNX runtime glue: `onnx_runtime_model`, `vocabulary`, `similarity_engine`, `similarity_search`, `search`, `embedding_pipeline`, `protocols{,_registry}`, `lru_cache` |
| `cache/` | `base_cache`, `language_cache`, `model_cache`, `frequency_cache`, plus `lookup_cache` / `suggestion_cache` runtime caches |
| `language/`, `languages/` | Detection (`identifier`, `detector`), registry, per-language modules, tokenizers, normalizers |
| `documents/` | Document abstraction: `plain_text_document`, `markdown_document`, `asciidoc_document`, `location` |
| `cli/` | CLI helpers (interactive reviewer, batch reporter, navigation, display) |
| `commands/` | Thor subcommands: `check_command`, `cache_command`, `model_command` |
| `grammar/` | Rule engine + pattern matchers (`rule`, `rule_engine`, `rule_loader`, `pattern_matchers/*`) |
| `keyboard/` | Layout registry + per-layout files (qwerty, qwertz, azerty, jcuken, dvorak) |
| `components/`, `plugins/`, `data_structures/`, `results/`, `data/` | Tokenizer/POS/synthesizer components, plugin registry, bloom filter, result base, common-words loader |

The exe uses `Kotoshu::Cli::Cli` (in `cli.rb`), which registers `dict` → `DictCommand` and `cache` → `CacheCommand` as subcommands. A richer `Kotoshu::CheckCommand` exists in `commands/check_command.rb` (with `--interactive`, `--format sarif/json`, `--model`, `--language auto`) — check which one is actually wired before assuming a CLI flag exists.

## Specs

Spec layout mirrors lib: `spec/kotoshu/...`, plus `spec/integration/`, `spec/integrational/`, `spec/performance/`, `spec/benchmark/`, `spec/properties/`, `spec/unit/`, `spec/hunspell_tests/` (Splylls-ported fixtures), `spec/fixtures/`, `spec/support/`.

Global rules that apply here (see `~/.claude/CLAUDE.md`): **no `double()` in specs** — use real instances or `Struct.new`; **no hand-rolled serialization** (`to_h`/`from_h` on models).

## Reference Implementations (read-only, on disk)

When implementing features, study these alongside Kotoshu:

- `/Users/mulgogi/src/external/hunspell/` — morphological rules, affix processing, suggestions (C++ reference).
- `/Users/mulgogi/src/external/cspell/` — trie/DAFSA dictionaries, code-aware checking (TypeScript reference).
- `/Users/mulgogi/src/external/languagetool/` — rule-based grammar, multi-interface (library + HTTP), caching patterns (Java reference).
- Spylls (Python Hunspell port) — the algorithms in `algorithms/` and the fixtures in `spec/hunspell_tests/` derive from here.

## Other Notes

- License is **BSD-2-Clause** (not MIT — the README's "License" section is wrong).
- RBS signatures live in `sig/kotoshu.rbs` (the `sig/kotoshu/` subdirectory is empty). Update signatures when changing public APIs.
- `scripts/` contains one-off utilities (FastText→ONNX conversion in Python, Kelly frequency parsing, diagnostics). `examples/` has numbered walkthrough scripts (`01_*.rb` … `07_*.rb`).
- Design history and superseded planning docs live in `docs/` (`architecture.md`, `cache-architecture.md`, `performance.md`, `plugins.md`, `getting-started.md`, plus integrated planning docs like `KOTOSHU_SOLIDIFICATION_PLAN.md`, `ARCHITECTURE_IMPROVEMENTS.md`, `TDD_ITERATION_STRATEGY.md`). Treat them as historical context, verify against current code before relying on them. `TODO.impl/` is the current source of truth for execution plans.
