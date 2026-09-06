# 04 — Language Modules

## Goal

Every language in `kotoshu/dictionaries` (98 dirs) is reachable through
the same `Language::*` module system, with the right tokenizer,
normalizer, keyboard layout, and resource bindings.

## Why

The current code ships 7 language modules under `lib/kotoshu/languages/`
(de, en, es, fr, ja, pt, ru) and 8 tokenizers under
`lib/kotoshu/language/tokenizer/`. The `dictionaries` repo exposes 98
language codes. The gap is the user-visible "all languages" promise.

## Tasks

1. **Language module contract.** Codify what
   `Kotoshu::Language::Base` (in `language/languages/base.rb`) requires:
   - `code` (ISO 639-1, e.g. `"de"`)
   - `locale` (default, e.g. `"de-DE"`)
   - `script` (`:latin | :cyrillic | :cjk | :rtl`)
   - `tokenizer_class`
   - `normalizer_class`
   - `keyboard_layout` (symbol)
   - `dictionary_source` (URL/path within `dictionaries` repo)
   - `frequency_source` (URL/path within `frequency-list-kelly` repo, or
     nil)
   - `model_source` (URL/path within `models-fasttext-onnx` repo, or
     nil)
   - `grammar_rules_path` (within `dictionaries/{code}/grammar/`, or
     nil)
2. **Audit the dictionaries repo** (cross-references
   `dictionaries/TODO.impl/02-coverage-matrix.md`) and register a module
   for every code that has at least a `spelling/` dir. Generate the
   module files from a template rather than hand-writing 90+ files.
3. **Tokenizer coverage.** Latin languages share `LatinTokenizer`; map
   each Latin language to it with locale-specific overrides
   (contractions for fr/it/es, ß handling for de, etc.). Cyrillic uses
   the same family. CJK and RTL get dedicated tokenizers (covered in
   plans `06` and `07`).
4. **Normalizer coverage.** Per-language normalization rules (case
   folding, accent stripping where appropriate, Unicode NFC).
5. **Keyboard layouts.** Currently `keyboard/layouts/` has qwerty,
   qwertz, azerty, jcuken, dvorak. Add layouts needed by the rest of
   the matrix (e.g. Turkish F, Arabic, Hebrew).
6. **Language auto-detection contract.** `Language::Identifier` returns
   ISO 639-1 codes; ensure every code it can return has a registered
   module. If detection returns an unsupported code, fall back to
   English with a warning.
7. **Language-specific resource URL templates.** Centralize the URL
   patterns in `LanguageCache`/`FrequencyCache`/`ModelCache` so a new
   language module doesn't need to repeat them.
8. **`Kotoshu.supported_languages` accuracy.** Currently returns
   `Language.supported_codes`; ensure this is the source of truth for
   the README's language matrix and the CLI's `--language` enum.

## Acceptance criteria

- Running `Kotoshu.supported_languages.size` returns ≥ 90 (matching
  dictionaries repo coverage)
- For every language code in
  `dictionaries/*/spelling/index.dic`, a corresponding
  `lib/kotoshu/languages/{code}/language.rb` exists and is registered
- A new integration spec `spec/integration/all_languages_spec.rb`
  iterates every supported language and asserts that
  `ResourceManager.resolve(text: sample_text, language: code)` returns
  a valid `ResourceBundle` with a non-nil `dictionary`. Tag `:network`.
- README's "Language Support Matrix" is generated from code, not
  hand-maintained

## Dependencies

- Blocks: nothing directly, but enables v1 release
- Blocked by: `01-hunspell-correctness` (need correct morphological
  path), `03-dynamic-download` (need resource resolution)
- Cross-repo: depends on `dictionaries/TODO.impl/02-coverage-matrix.md`
  being current

## Out of scope

- CJK and RTL tokenizers (separate plans `06`, `07`)
- New grammar rules per language (plan `08`)
- Custom dictionaries users might supply (already supported via
  `Dictionary::Custom`)

## Status

_Pending._
