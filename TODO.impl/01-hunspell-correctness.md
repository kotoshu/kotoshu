# 01 — Hunspell Correctness

## Goal

Pass 100% of the Spylls-ported fixture suite in `spec/hunspell_tests/` and
the Hunspell reference fixtures under
`/Users/mulgogi/src/external/hunspell/tests/`. Baseline at the start of
this plan was **48/107 (45 %)** passing; current state per
`CHANGELOG.md` is **803/866 (92.7 %)** — close but not done.

## Why

The lookup/affix/compound machinery is the foundation of the
traditional path; nothing downstream (suggestions, grammar,
multi-language) can be trusted until this is correct.

## Current blockers

- `lib/kotoshu/algorithms/lookup.rb` is a procedural ~877-line Python
  port; hash/array passing instead of domain models.
- Overlap between `Lookup`, `LookupBuilder`, `Lookuper` (not MECE).
- Affix data split between `AffReader`, `aff_data.rb`, `lookup.rb`.
- Missing: complex compounding, circumfix, ICONV/OCONV, German ß,
  Turkish dotless-i, special-character handling.

## Tasks

1. **Audit current pass rate.** Run `bundle exec rspec spec/hunspell_tests/`
   and `bundle exec rspec spec/integration/`. Record the actual number
   and failing fixture names in "Status" below.
2. **Compound rules.** Implement `COMPOUNDRULE`, `COMPOUNDFLAG`,
   `COMPOUNDBEGIN/MIDDLE/END`, `COMPOUNDPERMFLAG`, `COMPOUNDMIN`,
   `CHECKCOMPOUNDREP`, `CHECKCOMPOUNDCASE`, `CHECKCOMPOUNDTRIPLE`,
   `CHECKCOMPOUNDDUP`, `FORBIDDENWORD` inside compounds.
3. **Circumfix.** Bidirectional prefix+suffix via `CIRCUMFIX` flag.
4. **ICONV / OCONV.** Input/output character conversion tables applied
   at the right point in the pipeline.
5. **Special characters.** German ß uppercasing, Turkish dotless-i,
   Dutch IJ, Break patterns (`BREAK`), `IGNORE` chars, `CHECKSHARPS`,
   Arabic character ignoring, UTF-8 BOM, legacy encodings
   (Windows-1251).
6. **MECE refactor of the lookup pipeline.** Replace the procedural
   `lookup.rb` with a four-layer separation (per the reimplementation
   plan):
   - **Dictionary layer** (data structures): `WordRepository`,
     `AffixRepository`, `CompoundRuleRepository`,
     `MorphologicalAnalyzer`.
   - **Lookup layer** (algorithms): `WordLookup`, `AffixLookup`,
     `CompoundLookup`, `MorphologicalLookup`.
   - **Validation layer** (business rules): `ConditionValidator`,
     `FlagValidator`, `CompoundValidator`,
     `CapitalizationValidator`.
   - **Transformation layer** (operations): `AffixApplier`,
     `AffixStripper`, `WordFormer`, `CompoundFormer`.
   Collapse `Lookup`/`LookupBuilder`/`Lookuper` into one responsibility
   boundary or document why three classes exist.
7. **Domain-model completion.** Verify `Word`, `AffixRule`,
   `CompoundWord`, `Condition` carry the behavior, not the services
   (per the global "models first" rule). Query methods required:
   `word.stem`, `word.has_flag?(:verb)`, `word.forms`,
   `affix_rule.valid_for?(stem)`, `affix_rule.apply(stem)`,
   `affix_rule.can_combine?(other)`, `compound.valid_at?(position)`,
   `condition.matches?(stem)`.
8. **Strangler-Fig migration.** Build the new pipeline alongside the
   old; expose a configuration switch (e.g.
   `Configuration.use_modern_lookup` defaulting to `false`) so the
   cutover is per-language and reversible. Remove the old
   `algorithms/lookup.rb` only after the new path passes every fixture
   the old one did.
9. **Port the failing Spylls integrational fixtures** as named spec
   examples: `dotless_i`, `IJ`, `ignore`, `checksharps`, `break`,
   `needaffix`, `onlyincompound`, `alias`, `complexprefixes`,
   `germancompounding`, `checkcompoundpattern`, plus the Hunspell
   reference corpus fixtures (`1463589` Turkish UTF-8, `1592880`,
   `1695964`, `1706659`, `1748408`, `breakdefault`, `breakoff`,
   `encoding`, `utf8`, `utf8_bom`, `utf8_bom2`, `ignoreutf`,
   `ignoresug`, `checksharpsutf`).
10. **Performance baseline.** Profile lookup, affix application, and
    compound check; add `spec/performance/lookup_bench.rb` with
    assertions.

## Acceptance criteria

- `bundle exec rspec spec/hunspell_tests/` is green (100 % of Spylls
  fixtures).
- New specs added for every behavior fixed (no fixture passes
  silently).
- `lib/kotoshu/algorithms/lookup.rb` is under 400 lines, or its
  responsibilities have been redistributed across the four layers
  above with the boundary documented.
- **Performance:** < 100 ms average lookup time per 1000 words;
  < 100 MB memory for the en_US dictionary.
- **Code quality:** ≤ 50 lines per method, ≤ 300 lines per file, no
  primitive obsession (domain models, not raw hashes), SRP followed,
  dependencies on abstractions.
- No `double()` in any new spec (project rule — see `CLAUDE.md`).

## Dependencies

- None inside this repo. Blocks `04-language-modules` (which assumes
  a trustworthy Hunspell path) and `11-release`.

## Out of scope

- Suggestion quality tuning (covered in `05-semantic-path`).
- Grammar rules (covered in `08-grammar-engine`).
- New languages beyond what the existing fixture suite covers.

## Status

_Pending — fill in actual pass rate after task 1._
