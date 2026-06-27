# 39 — Tier 3 and Beyond

## Goal

The long-form backlog. Each item here is a *capability* rather than a
bug fix. Items are roughly prioritized; the order is not a commitment.

This file exists so we don't lose institutional memory between
releases. When an item becomes the next priority, promote it to its
own `TODO.impl/{n}-{name}.md` file with phases and acceptance criteria,
then delete the entry here.

## T3 — Capabilities

### T3.1 — CJK support (promote from `TODO.impl/06-cjk-support.md`)

Status: outline only. Real work needs:

- Tokenizer that handles Chinese (no spaces), Japanese (mixed kana /
  kanji), Korean (spaces + Hangul).
- Dictionary format: CJK dictionaries don't have affixes; they're
  frequency-sorted word lists.
- Suggestion strategy: edit-distance on Unicode codepoints is wrong;
  need pinyin (zh) / romaji (ja) / romanization (ko) aware edit distance.
- suika (current tokenizer) has segmentation; verify CJK coverage.

Reference: `/Users/mulgogi/src/external/cspell/` has a working CJK
implementation in TypeScript; port the algorithms, not the code.

### T3.2 — RTL support (promote from `TODO.impl/07-rtl-support.md`)

Status: outline only. Real work needs:

- Arabic / Hebrew normalizers (NFC, ligature handling, diacritic stripping).
- RTL-aware display in the CLI batch reporter and interactive reviewer.
- Right-to-left mark / left-to-right mark handling in the tokenizer
  (see `spec/integrational/fixtures/right_to_left_mark.*`).

### T3.3 — Grammar engine (promote from `TODO.impl/08-grammar-engine.md`)

Status: skeleton in `lib/kotoshu/grammar/`. Real work needs:

- Rule format stabilized (currently `Rule` + `PatternMatchers::*`).
- A first useful rule set (probably article/confusion pairs: a/an,
  its/it's, their/there/they're).
- Integration with the semantic analyzer for context-aware rules.
- A way to load rule packs per language.

Reference: `/Users/mulgogi/src/external/languagetool/` (Java) for rule
shape and category taxonomy. Don't reimplement LT's category model
verbatim — port the *shape*, not the 5000-rule corpus.

### T3.4 — Document plugins

The boundary is decided (see `kotoshu-document-plugin-boundary.md`
memory): kotoshu never owns document parsing. Existing plugins:

- `coradoc-plugin-kotoshu` (AsciiDoc via coradoc).
- Markdown: kotoshu has a built-in `documents/markdown_document.rb`.
  This violates the boundary; migrate to a plugin or formalize the
  exception.
- Plain text: built-in, keep.
- reStructuredText, Org, HTML, LaTeX, etc.: community plugins.

Work: define the `Kotoshu::Plugin::Document` interface and the
registration mechanism, then audit existing built-ins against it.

### T3.5 — Multi-language document checking

Right now `Kotoshu.check_file` is single-language. Real documents mix
languages (code comments in English + prose in French, etc.).

Work:

- Per-paragraph language detection via `Language::Identifier`.
- Per-language dictionary resolution.
- Result aggregation across languages.

### T3.6 — Personal dictionary management

The personal dictionary (`~/.config/kotoshu/personal_dictionary.txt`
or similar) exists but is undertested. Work:

- CLI for add/remove/list/import.
- Per-project personal dictionaries (`.kotoshu/` in project root).
- Sync with Hunspell-style personal dict format for interop.

## T4 — Quality

### T4.1 — Performance pass

`spec/benchmark/` and `spec/performance/` exist but are skipped by
default. Work:

- Establish baselines for: cold-start, lookup throughput,
  suggest latency at 1k/10k/100k dictionary size.
- Profile the hot path (`Kotoshu.correct?`); attack the biggest
  offender.
- Consider Memoization, Trie compression, Bloom filter tuning.

### T4.2 — CI

GitHub Actions workflow that runs:

- `bundle exec rspec --tag ~network --tag ~onnx` on every push.
- `bundle exec rubocop` on every push.
- `NETWORK_TESTS=1 bundle exec rspec` nightly on `main`.
- `ONNX_TESTS=1 bundle exec rspec` nightly on `main` (separate job;
  cache the model).

### T4.3 — Property-based testing

`spec/properties/` exists but is thin. Expand:

- Trie: insertion is order-independent; lookup is total.
- Suggestion generator: `suggestions.include?(word)` implies
  `dictionary.lookup?(word)` is true (no out-of-dictionary suggestions).
- Hunspell affix application: affixed forms round-trip through the
  stemmer.

### T4.4 — Documentation pass

- README.adoc: audit against actual CLI shape; remove 0.2-era examples.
- `docs/`: prune superseded planning docs; mark historical ones as
  historical.
- YARD: every public API has a docstring; private APIs are marked
  `@private`.

## T5 — Architecture

### T5.1 — MECE refactor of `suggestions/strategies/`

Current strategies overlap (e.g. `symspell` and `edit_distance` both
generate edit-distance-1 candidates). Refactor:

- Each strategy owns a *unique* candidate-generation mechanism.
- `CompositeStrategy` merges and ranks, doesn't dedupe by side effect.
- Strategies are pure functions of `(word, dictionary) → candidates`;
  no shared state, no global config reads.

### T5.2 — Configuration as data, not singleton

`Configuration.instance` is a process-wide singleton. Hard to test,
hard to scope per-document. Refactor:

- Pass a `Configuration` instance explicitly to `Spellchecker.new`.
- Default the facade (`Kotoshu.correct?`) to a process-default instance.
- Drop the singleton.

### T5.3 — Result model consistency

`WordResult` / `DocumentResult` / `SuggestionSet` migrated to
`lutaml-model` in 0.3.0. Audit:

- All three have consistent `to_hash` / `from_hash` shapes.
- No hand-rolled `to_h` anywhere (per global rule).
- CLI consumers use the framework-supplied serialization.

### T5.4 — Plugin architecture formalization

`Kotoshu::Plugin::*` exists but is informal. Define:

- Plugin discovery (`Gem.find_files` or explicit `Kotoshu::Plugin.register`).
- Plugin lifecycle (load, configure, start, stop).
- Plugin capabilities (document parser, suggestion strategy, language
  module, output format).

## T6 — Ecosystem

### T6.1 — VSCode / LSP integration

A language server that runs kotoshu on save, reports diagnostics via
LSP. Probably a separate gem (`kotoshu-lsp`).

### T6.2 — Web playground

A WASM build of kotoshu running in the browser. Requires a pure-Ruby
path (no native extensions) and a reasonable dictionary size budget.

### T6.3 — Dictionary editor GUI

A desktop app (Tauri / Electron) for curating personal dictionaries and
custom affix files. Reads/writes Hunspell format.

## Acceptance criteria for T3+ releases

Each item, when promoted, gets its own acceptance criteria. The
overarching rule: **never break T1/T2 correctness for a T3+ feature**.
Re-run the full `--tag ~network --tag ~onnx` suite before tagging any
T3+ release.

## Dependencies

- **Blocked by:** T1 (`TODO.impl/36`) and T2 (`TODO.impl/37`) — the
  baseline must be green before adding features.
- **Blocks:** nothing. This is the long horizon.
