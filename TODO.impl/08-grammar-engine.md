# 08 — Grammar Engine

## Goal

Ship a LanguageTool-style rule engine that loads per-language rule packs
from `dictionaries/{code}/grammar/rules.yaml`, runs pattern matchers
during analysis, and produces the same `WordResult`-style findings as
spellcheck errors.

## Why

The `grammar/` module exists (`lib/kotoshu/grammar/` — `rule.rb`,
`rule_engine.rb`, `rule_loader.rb`, `pattern_matchers/`) and there are
matchers for double_negative, possessive_context, vowel_sound. But:

- No rules are shipped in `dictionaries/*/grammar/rules.yaml` (README
  marks it as "future")
- The engine isn't wired into the `Spellchecker.check` pipeline
- The CLI doesn't expose `--grammar on|off`
- No language has a meaningful rule pack

## Tasks

1. **Rule schema.** Finalize the YAML schema
   `dictionaries/{code}/grammar/rules.yaml`:
   ```yaml
   version: 1
   language: en
   rules:
     - id: EN_A_VS_AN
       category: GRAMMAR
       description: "Use 'an' before vowel sounds"
       pattern:
         type: regex
         before: '\b([aA])\s+([aeiouAEIOU]\w*)'
       suggestion: 'an \2'
       examples:
         - incorrect: "a apple"
           correct: "an apple"
   ```
2. **Wire the engine into Spellchecker.** After dictionary lookup,
   `Grammar::RuleEngine.new(rules).apply(tokens)` runs and appends
   findings to the `DocumentResult`. Each finding has `category`
   (`GRAMMAR`, `STYLE`, `TYPOS`, `CONFUSION_WORDS`) so output can
   filter.
3. **Loader integration.** `ResourceManager` (plan `03`) loads
   `grammar/rules.yaml` as part of the resource bundle for any language
   that ships one.
4. **Pattern matcher coverage.** Beyond the three current matchers,
   add:
   - `regex_matcher` — generic regex-based pattern
   - `confusion_matcher` — pair-based confusion (的/得, à/a)
   - `repetition_matcher` — doubled words ("the the")
   - `capitalization_matcher` — sentence-start capitalization
5. **Rule disable/enable.** Configuration:
   - `Kotoshu.configure { |c| c.disabled_rules = %w[EN_A_VS_AN] }`
   - CLI: `--disable-rule ID`, `--enable-only-category GRAMMAR`
6. **Per-language rule packs.** For each of the 6 fully-supported
   languages, ship a starter pack of 10-20 high-confidence rules
   sourced from LanguageTool's open-source rule sets (license: LGPL).
   Coordinate cross-repo with `dictionaries/TODO.impl/02-coverage-matrix.md`.
7. **Rule test fixtures.** Every rule has positive and negative
   examples in its YAML; the spec suite auto-discovers and tests them.
8. **Performance.** Rule matching must add < 20% to check latency for
   typical documents. Benchmark in `spec/performance/grammar_bench.rb`.
9. **Auto-correction.** `Kotoshu.correct(text)` / `check --apply` applies
   the top suggestion for each finding when confidence is above a
   threshold. Strategies: `:top` (always top suggestion), `:interactive`
   (prompt per finding — reuse `cli/interactive_reviewer`), `:smart`
   (skip when multiple equally-ranked suggestions exist). Default:
   `:smart`.

## Acceptance criteria

- `Kotoshu.check("I want to a apple.")` flags the a→an error
- `Kotoshu.check("the the cat")` flags the doubled word
- `kotoshu check file.txt --disable-rule EN_A_VS_AN` skips that rule
- Every shipped rule has passing examples in CI
- `dictionaries/en/grammar/rules.yaml` has ≥ 15 rules

## Dependencies

- Blocks: `06-cjk` (needs confusion rules), `07-rtl` (needs confusion
  rules), `11-release`
- Blocked by: `03-dynamic-download` (rule loading)
- Cross-repo: `dictionaries/TODO.impl/02-coverage-matrix.md` (rule
  packs must exist)

## Out of scope

- ML-based grammar models (n-gram error detection is in ROADMAP plan
  008 but defer from v1)
- Style scoring / "tone" suggestions
- Premium/paid rule packs

## Status

_Pending._

## Source

`docs/KOTOSHU_LANGUAGETOOL_GAPS.md` (dated 2026-01-30) is the reference for
the 11-language target matrix (en, fr, de, es, ru, ar, pt, zh-Hans,
zh-Hant, ja, ko) and per-language tokenization/normalization rules.
Tokenization and language-specific requirements feed `04-language-modules`;
CLI surface and output formats feed `02-cli-unification`.
