# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
