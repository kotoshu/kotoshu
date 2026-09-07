# The 1.0 Readiness Audit

Plan 109. Analysis and documentation only — no behavior change, no version
bump, no release. The version cut itself is an owner decision.

- Audited at: gem 0.10.0 (`lib/kotoshu/version.rb:4`), main @ 73b7fac.
- Companion policy draft: `docs/STABILITY-1.0.md`.
- Method: every inventory line cites the file that defines the surface.
  Reachability was verified by grep, not by assumption: a class being
  present under `lib/` is not the same as being wired to `exe/kotoshu`.

## Inventory

Verdicts: **stable** (freeze at 1.0), **deprecate-before-1.0** (needs a
deprecation cycle first), **accidentally-public** (internal or dead, 1.0
should privatize or delete).

### Ruby gem — module functions (`lib/kotoshu.rb`)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `configure` / `configuration` / `configuration=` | `lib/kotoshu.rb:98,109,127` | stable | Type-checked global swap (127-131). |
| `spellchecker` / `spellchecker_for` | `lib/kotoshu.rb:139,157` | stable | Cache-only; README-documented (README.adoc:18). |
| `resolve` | `lib/kotoshu.rb:179` | stable | Stage-2 resolve; README.adoc:364. |
| `setup` / `setup?` / `languages_setup` | `lib/kotoshu.rb:220,245,257` | stable | Stage-1 entry; idempotent; `want:`/`tier:`/local-source opts frozen. |
| `reset_spellchecker` | `lib/kotoshu.rb:268` | stable | Test/embedding seam. |
| `correct?` / `misspelled?` / `suggest` / `check` / `check_file` / `check_files` | `lib/kotoshu.rb:286,297,313,331,349,363` | stable | The hot path; strict two-stage contract is the product identity. |
| `detect_language` / `detect_language_with_confidence` / `setup_lid` / `setup_lid?` | `lib/kotoshu.rb:465,481,501,508` | stable | Native LID with heuristic fallback (plan 106). |
| `get_language` / `language_registered?` / `supported_languages` / `language` | `lib/kotoshu.rb:519,530,540,443` | stable | `language` is a trivial namespace accessor; keep. |
| `dictionary` / `trie` / `suggestion_pipeline` | `lib/kotoshu.rb:371,388,409` | stable | Convenience factories; exercised by `examples/04..06`. |
| `register_dictionary_type` / `register_suggestion_algorithm` | `lib/kotoshu.rb:422,433` | stable | The extension points; 1.0 must not narrow them. |
| `VERSION` | `lib/kotoshu/version.rb:4` | stable | |

### Ruby gem — core classes

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `Kotoshu::Spellchecker` public methods: `correct?`, `incorrect?`, `suggest`, `check_word`, `check`, `check_file`, `check_directory`, `tokenize`, `dictionary`, `reload_dictionary` | `lib/kotoshu/spellchecker.rb:118,130,143,164,196,242,265,280,308,315` | stable | Constructor kwargs (`dictionary:`, `config:`, `resource_bundle:`) frozen at 65. |
| `Kotoshu::Spellchecker::ASCII_WORD_REGEX` | `lib/kotoshu/spellchecker.rb:39` | accidentally-public | Internal fallback word-char set exposed as a constant. Freeze + document, or privatize (see deprecations). |
| `Kotoshu::Configuration`: `SCHEMA`, `DEFAULTS`, accessors, `get`, `key?`, `load_dictionary`, `reset_dictionary`, `source_registry`, `self.default/instance/instance=/reset` | `lib/kotoshu/configuration.rb:38,222,423,431,447,474,517,541,565,576,585` | stable | ENV contract (`KOTOSHU_*`) rides on SCHEMA — every key there is public surface. |
| `Configuration#dictionaries_url` / `#models_url` | `lib/kotoshu/configuration.rb:63-74` (SCHEMA), `:318-321` (attrs) | deprecate-before-1.0 | SCHEMA descriptions already say "Deprecated: use repos_base_url + pins via SourceRegistry". |
| `ResourceManager.setup/resolve/setup?/languages_setup`, `DEFAULT_WANT` | `lib/kotoshu/resource_manager.rb:69,97,21` | stable | Facade delegates here; two-stage model frozen. |
| `ResourceBundle` (`dictionary`/`frequency`/`model`/`rules`) | `lib/kotoshu/resource_bundle.rb` | stable | Consumed by `Kotoshu.resolve` (kotoshu.rb:179). |
| Exception hierarchy: `Error` + `DictionaryNotFoundError`, `InvalidDictionaryFormatError`, `ConfigurationError`, `SpellcheckError`, `AffixRuleError`, `ResourceNotCachedError`, `ResourceNotSetupError`, `ResourceResolutionError`, `IntegrityError`, `SuikaUnavailable` | `lib/kotoshu/core/exceptions.rb:8,14,32,54,72,90,106,122,136,156,177`; autoloaded `lib/kotoshu.rb:65-75` | stable | Message text is not frozen; class names are. |
| `Kotoshu::Paths` (XDG + `KOTOSHU_{CACHE,CONFIG,DATA}_PATH`) | `lib/kotoshu/paths.rb` | stable | On-disk layout is user-visible contract. |
| Autoloaded namespaces behind `Kotoshu::*` | `lib/kotoshu.rb:14-62` | stable (as namespaces) | Namespaces stay; member-by-member stability is YARD-documented per class. 1.0 freezes namespace existence, not every leaf. |
| Top-level singleton aliases `Kotoshu::LanguageCache`, `Kotoshu::LanguageIdentifier`, `Kotoshu::ModelCache`, `Kotoshu::SemanticAnalyzer` | `lib/kotoshu.rb:80,81,84,85` | accidentally-public | Zero hits in lib/, spec/, README; canonical homes are `Kotoshu::Cache::LanguageCache`, `Kotoshu::Language::*`, `Kotoshu::Cache::ModelCache`, `Kotoshu::Analyzers::SemanticAnalyzer`. |
| `Kotoshu::Debug`, `DebugLogger`, `Metrics`, `MetricsCollector` | `lib/kotoshu.rb:78-83`; `lib/kotoshu/debug_mode.rb`, `metrics_module.rb`, `metrics_collector.rb` | stable | Documented in their doc comments; `Kotoshu::Metrics.stats` is README-documented (README.adoc:211). |
| `Kotoshu::FluentChecker` / `Kotoshu::MultiLanguageChecker` | `lib/kotoshu/fluent_checker.rb`, `lib/kotoshu/multi_language_checker.rb` | deprecate-before-1.0 (or document) | Spec-covered (`spec/kotoshu/{fluent,multi_language}_checker_spec.rb`) but absent from README.adoc — decide: document or deprecate. |

### Ruby gem — framework integrations (all soft deps, plan 89)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `require "kotoshu/validators"` → `Kotoshu::Validators::SpellingValidator` (+ `ACTIVE_MODEL_LOADED`, `ActiveModelUnavailable`) | `lib/kotoshu/validators/spelling_validator.rb:10-99`; autoload `lib/kotoshu.rb:60` | stable | Placeholder class keeps constant resolvable without Rails (91-99). |
| `require "kotoshu/rspec"` → `Kotoshu::Rspec::Matchers` (`expect_words`, `expect_document`, `all_be_spelled_correctly`, `be_spelled_correctly(in:)`) | `lib/kotoshu/rspec.rb:26-160`; autoload `lib/kotoshu.rb:61` | stable | Matcher names are the contract. |
| `require "kotoshu/tasks"` → default `rake kotoshu:check`; `Kotoshu::Tasks::CheckTask` | `lib/kotoshu/tasks.rb:11`, `lib/kotoshu/tasks/check_task.rb:22` | stable | require-only (defining a task on load is the point — kotoshu.rb:56-59). |
| `require "kotoshu/jekyll"` → `Kotoshu::Jekyll::Generator` (+ `JEKYLL_LOADED`, `JekyllUnavailable`) | `lib/kotoshu/jekyll.rb:9-96`; autoload `lib/kotoshu.rb:62` | stable | Baseline honored via `Baseline::Store::DEFAULT_FILENAME`. |

### Ruby gem — conformance surface (the behavioral contract)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `conformance/vectors.jsonl` (2630 rows, committed) | `conformance/vectors.jsonl`; sync contract documented in `lib/kotoshu/conformance_exporter.rb:54-60` | stable — frozen expectations | `expected` records what the Ruby engine ACTUALLY returns, not linguistic truth (conformance_exporter.rb:31-37). |
| Row shape v0: `kind/language/dictionary/input/limit/expected`; suggestion keys `word,distance,confidence,source` | `lib/kotoshu/conformance_exporter.rb:16-29,80` | stable | Four-key shape shared with wasm and `ffi::ruby`. |
| `Kotoshu::ConformanceRunner` (`run`, `compare`, rake tasks) | `lib/kotoshu/conformance_runner.rb:26,72,97` | stable | Guards Ruby-vs-vectors and native-vs-Ruby equality. |
| `Kotoshu::ConformanceExporter` (`export`, corpora selection, `EXCLUDED_FIXTURES`) | `lib/kotoshu/conformance_exporter.rb:61-254` | stable | Deterministic re-export (44-53). |

### CLI (`exe/kotoshu` → `Kotoshu::Cli::Cli`)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| Commands: `check`, `setup`, `dict`, `cache`, `personal`, `completions`, `baseline`, `status`, `version` (`--version`/`-V`) | `lib/kotoshu/cli.rb:178,241,317-329,349,358-367` | stable | |
| Class options `--language/-l`, `--format/-f` (text,json,sarif), `--interactive/-i`, `--verbose/-v` | `lib/kotoshu/cli.rb:102-125` | stable | |
| `check` options `--baseline`, `--show-suppressed`, `--include`, `--exclude`, `--personal` | `lib/kotoshu/cli.rb:151-168` | stable | |
| `setup` options `--aff --dic --from --frequency --want --model --tier --force --strict --list` | `lib/kotoshu/cli.rb:214-240` | stable | |
| Exit codes 0/1/2/3 | `lib/kotoshu/cli.rb:92-97,145-149` | stable | Consumed by action-kotoshu (action.yml:178-179). |
| JSON output top-level keys; SARIF 2.1.0 shape | `lib/kotoshu/cli.rb:624-651,686-715` | stable | Machine-readable contract; additive keys only. |
| `cache` subcommands `list/info/clean/evict/download/purge/validate` | `lib/kotoshu/cli/cache_command.rb:27,50,79,101,133,166,184` | stable | |
| `personal` subcommands `add/remove/list/import/path/clear` | `lib/kotoshu/cli/personal_command.rb:28-89` | stable | |
| `baseline init` (`--output`, `--language`) | `lib/kotoshu/cli/baseline_command.rb:15-36` | stable | |
| `completions bash/zsh` | `lib/kotoshu/cli/completions_command.rb:13-26` | stable | Catalog is hand-maintained — must track command changes. |
| `fetch` (hidden alias of `setup`) | `lib/kotoshu/cli.rb:280-315` | deprecate-before-1.0 | Already hidden and labeled deprecated; remove at 1.0. |

### Ruby gem — accidentally-public legacy commands (the hazard block)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `::DictCommand` (top-level constant!) | `lib/kotoshu/cli.rb:10` | accidentally-public | Defined on `Object`, outside `module Kotoshu`. Pollutes the global namespace of every process that requires the gem; collides with any other gem defining `DictCommand`. Move under `Kotoshu::Cli` before 1.0. |
| `Kotoshu::Commands::CheckCommand` | `lib/kotoshu/commands/check_command.rb:4`; autoload `lib/kotoshu/commands.rb:9` | accidentally-public | Not wired into `Cli` (no `subcommand "check"` at cli.rb:317-329 — `check` is a method on `Cli` itself, cli.rb:178). Half-placeholder implementation; its hunspell path calls `SpellChecker.new` (check_command.rb:198) which resolves to nonexistent `Kotoshu::SpellChecker` (the real class is `Kotoshu::Spellchecker`) → `NameError` at runtime. Declares flags that do not exist on the real CLI (`--model`, `-o`, `csv/yaml` formats), contradicting cli.rb:108-113. Delete or privatize. |
| `Kotoshu::CacheCommand` | `lib/kotoshu/commands/cache_command.rb:4` | accidentally-public | Dead duplicate of the wired `Kotoshu::Cli::CacheCommand` (autoload cli.rb:70; subcommand cli.rb:321). Nothing requires this file (verified by grep); acknowledged as historical in `lib/kotoshu/commands.rb:7-8`. Still shipped in the gem (`spec.files` = `git ls-files`, kotoshu.gemspec:30-38). Delete. |
| `Kotoshu::Commands::ModelCommand` | `lib/kotoshu/commands/model_command.rb:4`; autoload `lib/kotoshu/commands.rb:10` | accidentally-public | No `kotoshu model` subcommand is registered anywhere. `convert` shells out to `scripts/convert_fasttext_to_onnx.py` (model_command.rb:33-36) — untracked in git, therefore NOT shipped in the gem, so the command cannot work as packaged. Delete. |

### Ruby gem — native extension

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| Optional Rust ext build (`extconf.rb`) | `kotoshu.gemspec:53`; `ext/kotoshu_native/extconf.rb` | stable | Soft: pure-Ruby is the complete fallback (gemspec:44-52). |
| `Kotoshu::Native.available?`, `Native.suggestion(row)`, `Native::Unavailable`, `Native::EXTENSION` | `lib/kotoshu/native.rb:49,65,35,39` | stable | Extension defines `Native::VERSION`, `Native::Error`, `Native::Dictionary.load/correct?/suggest` (native.rb:9-14). |
| `Kotoshu::NativeBackend.resolve` boundary (ruby/auto/native) | `lib/kotoshu/native_backend.rb:45-73` | stable | Accelerator-only boundary is documented and frozen. |

### wasm package (kotoshu-rs)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `KotoshuWasm` constructor `(affSource, dicSource)`, `correct(word)`, `suggest(word, limit?)`, static `VERSION` | `kotoshu-rs/kotoshu/src/ffi/wasm/mod.rs:165-174,178,185,152-155` | stable | Contents-not-paths loading; errors reject with the Rust message. |
| `loadModel(modelBytes, vocabBytes, bucketsBytes?)` → `KotoshuModel`; `.free()` | mod.rs:220-235,207-209 | stable | Optional third arg added by plan 103 — additive pattern to keep. |
| `rerank(model, word, context)` → number in [-1,1] | mod.rs:241-244 | stable | Mean-cosine contract documented (mod.rs:73-82). |
| `semanticSuggest(model, word, k?)` → `{word, score}[]` | mod.rs:252-266 | stable | |
| `loadLid(onnxBytes, vocabBytes)` → `KotoshuLid`; `detectLanguage(lid, text)` → `{code, score}` | mod.rs:281-287,293-300 | stable | Parity contract with the gem documented (mod.rs:84-94). |
| Suggestion row shape: exactly `word/distance/confidence/source` | mod.rs:48-54,190-198 | stable — frozen | Same four keys as the conformance vectors (`conformance_exporter.rb:80`). |
| npm identity | `kotoshu-rs/kotoshu-wasm/pkg/package.json:2,5` | needs a decision | Package name is `kotoshu-wasm` but every doc says `@kotoshu/wasm` (mod.rs:2-3); publication still blocked on npm org credentials. Decide the final name before 1.0 — npm names are sticky. |

### HTTP server (kotoshu-server)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `GET /` (metadata), `GET /v1/health`, `GET /v1/version`, `GET /v1/languages` | `kotoshu-server/openapi.yaml:15,25,35,45`; routes `lib/kotoshu/server/app.rb:290,300,306,311` | stable | |
| `POST /v1/check` (`text`, `language`, `format`, `model`), `POST /v1/suggest` (`word`, `language`, `max` 1-50), `POST /v1/detect` (`text`) | openapi.yaml:55-117,179-203; routes app.rb:318,350,366 | stable | Errors: 400/422/503 shapes (openapi.yaml:118-137). |
| Response schemas `DocumentResult/WordError/Suggestions/Suggestion/Detection` (incl. `engine: lid-176|heuristic`) | openapi.yaml:204-245 | stable | openapi.yaml is the contract source of truth; app.rb matches it 1:1 (verified). |
| `/v1` prefix as the contract version | openapi.yaml:25-100 | stable | Breaking changes require `/v2`, not field mutations. |

### GitHub action (action-kotoshu)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| Inputs: `files, language, format, baseline, include, exclude, show_suppressed, fail_on_error, category, version, prewarm_languages, offline, output_path` | `action-kotoshu/action.yml:8-59` | stable — additive-only | New inputs must default to current behavior. |
| Outputs: `sarif-path`, `error-count` | action.yml:61-67 | stable | |
| Gem floor `>= 0.8.0` (v2 of the action) | action.yml:45,98-105 | stable | Floor bumps are breaking for the action and need a major action version. |

### Registry schema (models-fasttext-onnx)

| Surface | Where defined | Verdict | Note |
|---|---|---|---|
| `spec: "kotoshu.resources/v1"` (const) | `models-fasttext-onnx/schemas/registry.schema.json:15-17` | stable — frozen | Change requires a new spec string, never an edit. |
| Resource id pattern `kotoshu://models/(lid/lid-176|{lang}/(full|fluency|mini|buckets))` | registry.schema.json:35 | stable | Ids are never reused; content changes bump `release_tag` (schema description, registry.schema.json:5). |
| Resource object fields incl. `min_engine_version`, `sha256`, `license` | registry.schema.json:43-165 | stable | `additionalProperties: false` — additive fields need a schema change = coordinated release. |

## Deprecation list for the 1.0 cut

Concrete, with defining locations. All need small code PRs — deliberately
NOT implemented by this docs-only change.

1. `::DictCommand` — `lib/kotoshu/cli.rb:10`. Global-namespace leak from a
   file that otherwise lives in `Kotoshu::Cli`. Rename to
   `Kotoshu::Cli::DictCommand` (internal; `subcommand "dict"` wiring at
   cli.rb:317-318 is the only consumer). Highest-priority item: it can
   break other gems in the same process, which is exactly the class of
   thing 1.0 exists to prevent.
   Handled in this PR: the class moved to
   `lib/kotoshu/cli/dict_command.rb` as `Kotoshu::Cli::DictCommand`
   (autoloaded like its sibling subcommands); `::DictCommand` is gone.
2. `Kotoshu::Commands::CheckCommand` — `lib/kotoshu/commands/check_command.rb:4`
   (autoload `lib/kotoshu/commands.rb:9`). Unwired, placeholder-laden, and
   broken at check_command.rb:198 (`SpellChecker` → `NameError`; real class
   is `Kotoshu::Spellchecker`, spellchecker.rb:21). Its flag surface
   (`--model`, `-o/--output`, `csv|yaml` formats) contradicts the real CLI
   and will mislead users who find it via constants. Delete; keep
   `lib/kotoshu/commands.rb` as the namespace or remove both.
   Handled in this PR: deleted, along with the now-empty `Commands`
   namespace (file and autoload). No spec referenced it.
3. `Kotoshu::CacheCommand` — `lib/kotoshu/commands/cache_command.rb:4`.
   Dead duplicate of `Kotoshu::Cli::CacheCommand`; unreachable by any
   require in the repo; still shipped by the gemspec file list. Delete.
   Handled in this PR: deleted. No spec referenced it.
4. `Kotoshu::Commands::ModelCommand` — `lib/kotoshu/commands/model_command.rb:4`
   (autoload `lib/kotoshu/commands.rb:10`). No `model` subcommand exists;
   `convert` depends on an untracked Python script not shipped in the gem
   (model_command.rb:33-36 vs gemspec:30-38). Delete.
   Handled in this PR: deleted. No spec referenced it.
5. Alias constants `Kotoshu::LanguageCache`, `Kotoshu::LanguageIdentifier`,
   `Kotoshu::ModelCache`, `Kotoshu::SemanticAnalyzer` — `lib/kotoshu.rb:80,81,84,85`.
   No usage anywhere in lib/, spec/, or README. Add a deprecation `warn`
   in a 0.x minor and drop the autoloads at 1.0 (canonical names stay).
   Handled in this PR: grep confirmed zero references to the aliases
   anywhere (lib, spec, exe, docs, README, sig) — the short-name hits all
   resolve to the canonical constants lexically — so the autoloads were
   dropped straight away, ahead of the suggested warn cycle. Canonical
   names are untouched.
6. CLI `fetch` — `lib/kotoshu/cli.rb:280-315`. Already hidden and marked
   deprecated. Remove at 1.0.
7. `Configuration#dictionaries_url` / `#models_url` —
   `lib/kotoshu/configuration.rb:63-74,318-321`. Marked deprecated in SCHEMA
   since the SourceRegistry pins landed. Emit a warning on use, remove the
   SCHEMA entries at 1.0 (ENV vars `KOTOSHU_DICTIONARIES_URL` /
   `KOTOSHU_MODELS_URL` go with them — call that out in the changelog).
8. `Kotoshu::Spellchecker::ASCII_WORD_REGEX` — `lib/kotoshu/spellchecker.rb:39`.
   Internal fallback set posing as API. Either document + freeze or make it
   private before 1.0.
   Handled in this PR: zero external references confirmed by grep, so the
   constant was deleted and its literal inlined at the single internal use
   site (constructor fallback). Behavior unchanged.
9. `Kotoshu::FluentChecker` / `Kotoshu::MultiLanguageChecker` —
   `lib/kotoshu/fluent_checker.rb`, `lib/kotoshu/multi_language_checker.rb`.
   Spec-covered but undocumented in README.adoc. Decide per class: document
   as stable, or deprecate. Do not freeze silently.
   Handled in this PR: both class docstrings now state "Experimental and
   not public API: outside the 1.0 stability freeze, may change or be
   removed without a deprecation cycle." Specs stay.
10. wasm npm identity — `kotoshu-rs/kotoshu-wasm/pkg/package.json:2` says
    `kotoshu-wasm` while `kotoshu-rs/kotoshu/src/ffi/wasm/mod.rs:2-3` and
    all docs say `@kotoshu/wasm`. Resolve before first publication; the
    audit treats the documented scoped name as intended.
    Handled in this PR: verified, no code change needed.
    `kotoshu-rs/scripts/wasm_build.sh` rewrites the generated
    `package.json` name to `@kotoshu/wasm` on every build (the source
    manifest name is a wasm-pack crate-name artifact; `pkg/` is a
    gitignored build output). The shipped identity is already
    `@kotoshu/wasm`; the owner decision that remains is publication
    credentials, not the name.

## 1.0 checklist

Known blockers — none are mechanical code fixes; all are owner decisions
or ecosystem plumbing, stated honestly:

1. Dispositions for the ten deprecation items above (small code PRs; this
   audit only records them).
2. npm org + publish credentials for `@kotoshu/wasm` (and the name
   decision, item 10). The wasm build exists; publication is blocked.
3. The JS SDK PR (kotoshu-js #1) still pending merge — the HTTP contract
   it consumes must be the frozen one.
4. PyPI token for kotoshu-python publication (same train).
5. kotoshu-server is at 0.1.0 with an unexplained prewarm hang noted in
   ecosystem state — the 1.0 train should not ship a server cut with a
   known hang.
6. RBS coverage: `sig/kotoshu.rbs` should be checked against the frozen
   surface so the types do not contradict the freeze.
7. Conformance vectors green on both engines
   (`rake kotoshu:conformance:compare`) at the cut commit.

Release-train shape (gem + wasm + server together, per plan):

- Cut order: registry release_tag (if models moved) → gem 1.0 → wasm
  package (independent version line, same day) → server (depends on the
  gem floor) → action (no code change; floor stays 0.8.0-compatible, or
  bump with an action major).
- The conformance vectors must be byte-identical across the train: they
  are re-exported only when engine behavior intentionally changes, and
  any such change is exactly what the deprecation window is for.
- Docs: this audit + `docs/STABILITY-1.0.md` land first (this PR); the
  policy takes effect the day 1.0 ships.

What stays post-1.0 (policy constants, see the policy draft):

- The strict two-stage model — `setup` is never implicit; the hot path
  never downloads.
- Soft-dependency policy for onnxruntime, suika, activemodel, jekyll.
- XDG paths + `KOTOSHU_*` envs as documented configuration surface.
- CLI exit codes 0/1/2/3 and the JSON/SARIF output shapes.
- `kotoshu.resources/v1` and the `/v1` HTTP prefix.
