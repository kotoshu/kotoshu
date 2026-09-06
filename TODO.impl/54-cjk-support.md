# 54 — CJK support (T3.1)

## Goal

Real CJK (Chinese, Japanese, Korean) spell and grammar checking.
This is the largest tier 3 item: CJK languages need word-segmentation
(no spaces in zh/ja), different dictionary formats, and
romanization-aware suggestion strategies.

Status: outline only. This TODO documents the design space; real work
needs upstream library choices and per-language fixture data.

## Per-language needs

### Chinese (zh)

- **Tokenizer**: needs word segmentation. Options:
  - `jieba-ruby` (port of the Python jieba) — HMM + dictionary-based.
  - `suika` (already a kotoshu dependency for Japanese) has some CJK
    support — verify coverage.
- **Dictionary format**: frequency-sorted word lists, not Hunspell.
  CJK dictionaries don't have affixes.
- **Suggestions**: edit distance on Unicode codepoints is wrong (zh
  characters are logographic). Need pinyin-aware edit distance:
  - Map each character to its pinyin romanization.
  - Edit-distance on pinyin, then map back to characters.
  - Requires a `pinyin-ruby` gem or port of `pypinyin`.

### Japanese (ja)

- **Tokenizer**: `suika` already integrated. Works for kana + kanji.
- **Dictionary format**: frequency-sorted word lists.
- **Suggestions**: romaji-aware edit distance. Map kana → romaji via
  `romaji` gem, then edit-distance on romaji.

### Korean (ko)

- **Tokenizer**: Korean HAS spaces but morphological analysis is
  needed for accurate word boundaries. Options:
  - `korean-stemmer` (pure Ruby port of mecab-ko).
  - Or treat Korean like Latin-family languages (use space-split).
- **Dictionary format**: word lists.
- **Suggestions**: romanization via `romaja` or similar.

## Design space

### New tokenizer base classes

    class Kotoshu::Language::Tokenizer::CJKTokenizer < Base
      # Subclasses: ChineseTokenizer, JapaneseTokenizer, KoreanTokenizer
    end

Each owns its segmentation algorithm and dictionary interaction.

### New suggestion strategy

    class Kotoshu::Suggestions::Strategies::RomanizationStrategy < BaseStrategy
      # Edit distance on romanized form, then map candidates back to
      # the original script.
    end

Registered alongside the existing edit_distance, phonetic, etc.

### New dictionary backend

    class Kotoshu::Dictionary::FrequencySorted < Base
      # CJK dictionaries don't have affixes. Just a frequency-sorted
      # word list, optionally with POS tags.
    end

## Phases

### Phase 0 — Survey (this TODO)
- Pick segmentation libraries (suika / jieba-ruby / etc.).
- Confirm license compatibility.
- Identify fixture sources (CC-CEDICT, JMDict, KRDict).

### Phase 1 — Japanese (smallest scope)
- Tokenizer already exists (suika-backed `JapaneseTokenizer`).
- Add frequency-sorted dictionary backend.
- Add romaji-aware suggestion strategy.
- Specs with a small JMDict extract.

### Phase 2 — Chinese
- Add `jieba-ruby` as a soft dependency.
- New `ChineseTokenizer`.
- Pinyin mapping.
- Specs with a small CC-CEDICT extract.

### Phase 3 — Korean
- Decision on morphological analysis (mecab-ko vs simple split).
- Specs.

## Acceptance criteria

- [ ] `kotoshu setup :ja` produces a working Japanese checker that
      detects and suggests corrections for non-words.
- [ ] Same for Chinese and Korean.
- [ ] Suggestion quality on CJK typos is reasonable (top-3 contains
      the intended word in > 70% of test cases).
- [ ] No CJK-specific code in core kotoshu outside `languages/ja`,
      `languages/zh`, `languages/ko`, and the new strategy/backend.

## Dependencies

- **Blocked by:** none directly, but Phases 1-3 each need their
  upstream library chosen and bundled as soft deps.
- **Blocks:** nothing.

## Open questions

- Should we ship CJK dictionaries in `data/{lang}/` or only via
  dynamic download? Current direction: dynamic download (matches
  Latin languages).
- Is suika's Korean support real? Needs verification.
- For Chinese, jieba vs jieba-ruby vs python-subprocess? Performance
  and packaging tradeoffs.
