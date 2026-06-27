# 37 — Hunspell Correctness (Tier 2)

## Goal

Drive the integrational Hunspell-fixture suite (`spec/integrational/
{lookup,suggest}_spec.rb`) from its current ~90-failure state to a
**bounded, categorized, steadily green** state. T2 is *correctness
work on the reader/lookup/suggest core*, not a rewrite.

## Why this is T2

The fixtures are ported from
[`spylls`](https://github.com/neolithos/spylls) (Python) which itself
mirrors upstream Hunspell's `tests/` directory. Each fixture exercises
a single directive (`FLAG long`, `COMPOUNDRULE`, `CHECKCOMPOUNDPATTERN`,
…). The current Ruby port passes the easy ones and fails the ones that
exercise less-trafficked code paths.

This work is **not** a release blocker for 0.3.1 (see
`TODO.impl/36-cleanup-regressions-0.3.1.md`). It is the next tier.

## Source of truth

- Reference: `/Users/mulgogi/src/external/hunspell/` (C++ upstream).
- Reference: `spylls` (Python port) — `algorithms/` is a Ruby line-by-line
  port of `spylls/spylls/hunspell/`.
- Fixtures live in `spec/integrational/fixtures/` and are loaded via
  `SpyllsTestHelper` (mixed into every spec through `spec_helper.rb`).

## Phase structure

Each phase ends with a **green run on the fixtures it targets** plus a
commit on the T2 branch. The phases are independent — partial completion
still ships value.

### Phase 2A — Flag-format correctness

**Fixtures affected:** `flaglong`, `flagnum`, `flagutf8`, `alias`,
`alias2`, `alias3`.

**Root causes (hypothesized, verify before fixing):**

1. `FLAG long` mode: `parse_flags` in `aff_reader.rb` uses
   `string.scan(/../)` which fails on **odd-length** flag runs (the last
   char gets dropped). Real Hunspell pads/aligns differently per context
   (single flag = 2 chars, multi-flag = even run).
2. `FLAG num` mode: integer flags are parsed as strings, but downstream
   `Set` operations sometimes compare against integers.
3. `FLAG UTF-8` mode: surrogate-pair / multi-byte handling is incorrect
   on non-BMP characters (see also `utf8_nonbmp`).
4. `AF` flag aliases: aliases are looked up *per-rule* but should be
   resolved once at load time and stashed on the `Affix` instance.

**Acceptance:** the 10 fixtures above pass in both `lookup_spec` and
`suggest_spec` (where a `.sug` fixture exists).

### Phase 2B — Compounding

**Fixtures affected:** `compoundflag`, `onlyincompound`, `compoundaffix`,
`compoundrule{1..8}`, `checkcompoundcase{,2,utf}`,
`checkcompounddup`, `checkcompoundpattern{,2,3,4}`,
`checkcompoundrep`, `checkcompoundtriple`, `compoundforbid`,
`simplifiedtriple`, `wordpair`, `forceucase`, `utfcompound`,
`fogemorpheme`, `opentaal_cpdpat{,2}`, `opentaal_forbiddenword{1,2}`,
`germancompounding{,old}`.

This is the largest single cluster — roughly 30 fixtures.

**Approach:**

- Bring the Ruby `algorithms/suggest.rb` / `algorithms/lookup.rb` back
  in line with `spylls` commit-by-commit. Each fixture failure has a
  corresponding code path in spylls; find the divergence.
- The `COMPOUNDRULE` regex matcher (`CompoundRule#fullmatch` in
  `aff_data.rb`) has known issues with parenthesized flag groups —
  audit against spylls' `algorithms/compoundrule.py`.
- `CHECKCOMPOUNDPATTERN` with replacement (`/`-separated third field)
  is `pending` in `lookup_spec.rb` already; **finish** that work.

**Acceptance:** all 30 fixtures green. The three already-`pending`
`replacement in pattern` cases move from pending to passing.

### Phase 2C — Suggestion-quality

**Fixtures affected:** every fixture that has a `.sug` file in
`suggest_spec.rb`.

**Note:** suggestion output is order-sensitive and Hunspell's actual
output is the reference. We don't need *identical* output to upstream;
we need **the same set** with reasonable ordering. Where spylls asserts
ordering, mirror it; where Hunspell docs are silent, accept any
permutation.

**Approach:**

- `algorithms/ngram_suggest.rb`: port the latest ngram ranking from
  spylls.
- `algorithms/phonet_suggest.rb`: audit against spylls; the PhonetTable
  rule parser in `aff_data.rb` is the likely source of phantom
  suggestions.
- `REP` patterns are applied too eagerly in the suggester (fixed in
  T1 at the *reader* level; here we fix the *suggester* application).

**Acceptance:** every `suggest_spec` example either passes or carries
a documented `pending` with a concrete hypothesis.

### Phase 2D — Edge cases & language-specific

**Fixtures affected:** `1463589`, `1592880`, `1695964`, `1706659`,
`1975530`, `2970240`, `2970242`, `2999225`, `i35725`, `i53643`,
`i54633`, `i54980`, `i58202`, `slash`, `morph`, `ngram_utf_fix`,
`ph2`, `warn`, `korean`, `utf8_nonbmp`, `checksharps{,utf}`,
`dotless_i`, `IJ`, `nepali`, `allcaps{,2,3,_utf}`, `forbiddenword`,
`keepcase`, `nosuggest`, `iconv{,2}`, `oconv{,2}`,
`breakdefault`, `break`, `breakoff`, `fullstrip`, `zeroaffix`,
`needaffix{,2,3,4,5}`, `circumfix`, `condition{,_utf}`,
`conditionalprefix`, `complexprefixes{,2,utf}`, `affixes`,
`base{,_utf}`, `encoding`, `utf8{,_bom,_bom2}`,
`right_to_left_mark`, `ignore{,sug,_utf}`, `opentaal_keepcase`.

These are the bug-tracker cases (numbers are Hunspell GitHub issue
numbers) plus a long tail of single-directive edge cases.

**Approach:** bucket by directive; fix one bucket per PR.

**Acceptance:** `bundle exec rspec spec/integrational --tag ~network`
shows ≤ 5 failing examples (each with a documented `pending` and
an upstream link).

## Cross-cutting work

### C1. `SpyllsTestHelper` audit

The helper currently `include`s in every spec. The `read_dictionary`
helper loads fixtures by name and constructs a `Hunspell` dictionary.
Audit:

- Does it use `double()` anywhere? (Forbidden per global rule.)
- Does it bypass the public `Dictionary::Hunspell` API to poke at
  internals? If so, the API is the wrong shape — fix the API.
- Are the fixture paths resolved correctly under `bundle exec` versus
  direct invocation?

### C2. Reader/lookup OO refactor

The current `AffReader` returns a raw `Hash` with string keys. As T2
progresses, consider:

- A `Readers::AffData` value object (not a `Hash`) with typed accessors.
- A `Readers::DicData` parallel.
- The `Dictionary::Hunspell` constructor consumes `AffData`/`DicData`,
  not hashes.

This is **optional** for T2 correctness — only do it if a fixture
demands it. If pursued, do it as the **last** step so the bulk of T2
remains "fix the bug, don't reshape the code".

## Acceptance criteria for T2 release

- `bundle exec rspec spec/integrational --tag ~network` → ≤ 5 failing
  examples, each `pending` with an upstream issue link.
- `bundle exec rspec --tag ~network --tag ~onnx` → all green (T1 still
  green).
- `bundle exec rubocop` → clean.
- **No new public API changes.** T2 is internal correctness.

## Dependencies

- **Blocked by:** `TODO.impl/36-cleanup-regressions-0.3.1.md`. The
  integrational suite needs to be runnable on a clean baseline before
  we can track fixture-level regressions.
- **Blocks:** nothing in T3. T3 features (CJK, RTL, grammar) build on a
  correct core, but they can be developed in parallel branches against
  the current (pre-T2) state if needed.

## Out of scope

- Performance optimization (`spec/benchmark/`, `spec/performance/`).
  That's T4.
- New languages beyond what the fixtures cover. That's T3.
- Grammar engine. That's T3 (`TODO.impl/39-tier3-and-beyond.md`).
- ONNX semantic path correctness. That's `TODO.impl/38-onnx-semantic-gating.md`.
