# 56 — T4+ Quality, Architecture, and Ecosystem backlog

This file rolls up the T4 (Quality), T5 (Architecture), and T6
(Ecosystem) items from TODO.impl/39-tier3-and-beyond.md into
promotable units with concrete acceptance criteria.

## T4 — Quality

### T4.1 — Performance pass

Status: outline. Baseline measurements needed before optimization.

- `spec/benchmark/` and `spec/performance/` exist but are skipped by
  default (SLOW_TESTS=1).
- Establish baselines for:
  - Cold-start time (time to first `correct?` call).
  - Lookup throughput (correct? calls/sec on a 100k-word dictionary).
  - Suggest latency at 1k / 10k / 100k dictionary sizes.
- Profile the hot path (`Kotoshu.correct?`); attack the biggest
  offender. Likely candidates:
  - `IndexedDictionary` lookup: is it O(1)?
  - `Suggestions::Generator#generate`: is the strategy composition
    optimal?
  - `Trie` traversal: any obvious wins?
- Consider Memoization, Trie compression, Bloom filter tuning.

### T4.2 — CI matrix

- Workflow that runs `bundle exec rspec --tag ~network --tag ~onnx`
  on every push (already done).
- Workflow that runs `bundle exec rubocop` on every push (already done).
- Nightly workflow on main that runs `NETWORK_TESTS=1` (already done).
- Nightly workflow on main that runs `ONNX_TESTS=1` with cached models
  (already done).
- Add: weekly workflow that runs `SLOW_TESTS=1` benchmarks and
  publishes deltas to a dashboard.

### T4.3 — Property-based testing

Status: skeleton exists in `spec/properties/`.

- Trie: insertion is order-independent; lookup is total.
- Suggestion generator: `suggestions.include?(word)` implies
  `dictionary.lookup?(word)` is true (no out-of-dictionary
  suggestions).
- Hunspell affix application: affixed forms round-trip through the
  stemmer.

Expand each with at least 5 properties.

### T4.4 — Documentation pass

- README.adoc: audit against actual CLI shape; remove 0.2-era
  examples.
- `docs/`: prune superseded planning docs; mark historical ones as
  historical.
- YARD: every public API has a docstring; private APIs are marked
  `@private`.
- Add API docs publishing to CI (gh-pages).

## T5 — Architecture

### T5.1 — MECE refactor of `suggestions/strategies/`

Current strategies overlap (e.g. `symspell` and `edit_distance` both
generate edit-distance-1 candidates). Refactor:

- Each strategy owns a *unique* candidate-generation mechanism.
- `CompositeStrategy` merges and ranks, doesn't dedupe by side
  effect.
- Strategies are pure functions of `(word, dictionary) → candidates`;
  no shared state, no global config reads.

### T5.2 — Configuration as data, not singleton

`Configuration.instance` is a process-wide singleton. Hard to test,
hard to scope per-document. Refactor:

- Pass a `Configuration` instance explicitly to `Spellchecker.new`.
- Default the facade (`Kotoshu.correct?`) to a process-default
  instance.
- Drop the singleton.

### T5.3 — Result model consistency

`WordResult` / `DocumentResult` / `SuggestionSet` migrated to
`lutaml-model` in 0.3.0. Audit:

- All three have consistent `to_hash` / `from_hash` shapes.
- No hand-rolled `to_h` anywhere (per global rule).
- CLI consumers use the framework-supplied serialization.

### T5.4 — Plugin architecture formalization

See TODO.impl/53.

## T6 — Ecosystem

### T6.1 — VSCode / LSP integration

A language server that runs kotoshu on save, reports diagnostics via
LSP. Probably a separate gem (`kotoshu-lsp`).

### T6.2 — Web playground

A WASM build of kotoshu running in the browser. Requires a pure-Ruby
path (no native extensions) and a reasonable dictionary size budget.

### T6.3 — Dictionary editor GUI

A desktop app (Tauri / Electron) for curating personal dictionaries
and custom affix files. Reads/writes Hunspell format.

## Acceptance criteria per promotable item

Each item, when promoted from this file to its own
`TODO.impl/{n}-{name}.md`, gets its own acceptance criteria. The
overarching rule: **never break T1/T2 correctness for a T3+ feature**.
Re-run the full `--tag ~network --tag ~onnx` suite before tagging any
T3+ release.

## Dependencies

- **Blocked by:** T1 (`TODO.impl/36`) and T2 (`TODO.impl/37`) — the
  baseline must be green before adding features.
- **Blocks:** nothing. This is the long horizon.
