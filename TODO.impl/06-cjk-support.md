# 06 — CJK Support (Japanese, Chinese)

## Goal

Japanese and Chinese work end-to-end. CJK doesn't have "spelling" in the
alphabetic sense — the paradigm is morphological tokenization +
confusion-pair rules. Kotoshu should expose this honestly rather than
pretend a dictionary lookup works.

## Why

ROADMAP plan `004-japanese.md` and `005-chinese.md` are 🔲 Not Started.
The gem ships a `JapaneseTokenizer` skeleton under
`lib/kotoshu/language/tokenizer/` but no morphological backend, and a
`ja/language.rb` module with no real wiring. The `dictionaries` repo
has `ja/` and `zh/` dirs but only with `grammar/` subdirs (no
`spelling/`) — correct, since CJK doesn't use spelling dicts.

## Paradigm

| Concern | Latin | CJK |
|---|---|---|
| Spellcheck | Dictionary membership + affixes | N/A |
| Tokenization | Whitespace/regex | Morphological analyzer |
| Errors | Out-of-dict words | Confusion-pair rules (e.g. 辨/辯/辮) |
| Suggestions | Edit distance + phonetic | Confusion probability tables |

## Tasks

### Japanese

1. **Pick a morphological backend.** Options:
   - **Sen** (Java, requires JRuby — likely unacceptable for pure-Ruby
     promise)
   - **Suika** (already in the gemspec — pure Ruby MeCab-IPADic port,
     the right choice)
   - FFI to MeCab (breaks pure-Ruby promise)
   Decision: **use suika**. Add `Kotoshu::Language::Tokenizer::SuikaTokenizer`
   that wraps `Suika::Tagger`.
2. **Wire `JapaneseTokenizer`** to delegate to suika for segmentation +
   POS. Keep the existing class name for backward compatibility.
3. **Confusion rules.** Source a Japanese confusion-pair list (homophone
   kanji 食べる/搗ける etc.) and ship as
   `dictionaries/ja/grammar/confusion.yaml`. The grammar engine
   (plan `08`) reads it.
4. **Reading-check rules.** Kotoshi-specific (言修 = ことしゅ): verify
   furigana/reading correctness against jumbo dictionaries. Defer if
   out of scope for v1.
5. **No embedding model.** Japanese FastText exists upstream but the
   `models-fasttext-onnx` repo doesn't have `ja/`. Either convert it
   (cross-ref `models-fasttext-onnx/TODO.impl/01-publish-all-models.md`)
   or document Japanese as traditional-rules-only.

### Chinese

6. **Pick a segmenter.** Pure-Ruby options are limited. Options:
   - Hand-rolled maximum-matching against a word list (acceptable for
     v1, fast, deterministic)
   - FFI to HanLP (breaks pure-Ruby promise)
   - Port a small CRF model to Ruby (large effort)
   Decision: **ship max-matching with the existing dictionaries/zh word
     list for v1; note the accuracy ceiling in docs**.
7. **Simplified/Traditional** detection and cross-checking.
8. **Confusion rules.** Common confusions (的/得/地, 在/再, 做/作) ship
   as `dictionaries/zh/grammar/confusion.yaml`.

### Shared

9. **Update `Language::Base`** so `script: :cjk` languages declare
   `spell_checker: :passthrough` (use existing
   `Components::PassthroughSpellChecker`) and require a tokenizer.
10. **CLI flag `--model`** for CJK should reject `:hunspell` and
    `:hybrid` with a clear error explaining why.
11. **CJK-aware SARIF output.** Character offsets must be in Unicode
    codepoints, not bytes; verify the `Location` class in `documents/`
    handles this.

## Acceptance criteria

- `Kotoshu.check("私は 学生 です。")` tokenizes correctly and reports
  no errors (with default rules)
- `Kotoshu.check("私はがくせいです。")` flags the use of hiragana where
  kanji is conventional, with a confusion-rule suggestion
- `Kotoshu.check("他是在做好了。")` flags 的/得 confusion
- README documents that CJK is "rules + tokenization, no spellcheck"
  rather than silently producing nonsense

## Dependencies

- Blocks: nothing
- Blocked by: `03-dynamic-download` (need to fetch the suika dict or
  bundle it), `08-grammar-engine` (confusion rules need the engine)
- Cross-repo: `dictionaries/ja/grammar/` and `dictionaries/zh/grammar/`
  need content; coordinate with
  `dictionaries/TODO.impl/02-coverage-matrix.md`

## Out of scope

- Korean (similar paradigm but no plan written — add later)
- Full furigana generation
- Translation / ROMAJI conversion

## Status

_Pending._
