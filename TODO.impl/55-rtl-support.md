# 55 — RTL support (T3.2)

## Goal

Right-to-left script support: Arabic, Hebrew, Persian, Urdu. Covers
normalization, display, and tokenizer handling.

## Per-language needs

### Arabic (ar)

- **Normalizer**: NFC + ligature handling + diacritic stripping.
  Arabic has many presentation forms (U+FE70..U+FEFF) that should be
  canonicalized to base forms (U+0627..U+0645).
- **Tokenizer**: Arabic HAS spaces but morphological prefixes
  (ال, و, ب, ف, ل) attach to words. Need light stemming for lookup.
- **Suggestions**: edit distance on Unicode codepoints works (unlike
  CJK). Phonetic similarity via Soundex-like algorithm possible.

### Hebrew (he)

- **Normalizer**: NFC + dagesh + niqqud handling. Modern Hebrew is
  typically written without niqqud; for spell-checking, strip niqqud
  before lookup.
- **Tokenizer**: Hebrew HAS spaces. No prefix issues as severe as
  Arabic.
- **Suggestions**: edit distance on Hebrew codepoints.

### Persian (fa)

- Like Arabic but with Persian-specific letters (گ چ پ ژ ک ی).
- Normalizer should map Arabic Yeh (ي) to Persian Yeh (ی).

### Urdu (ur)

- Like Persian but written in Nastaliq style (calligraphic).
- Tokenization is the same as Persian; the visual rendering is a
  display concern, not a spell-check concern.

## Design

### New normalizer base class

    class Kotoshu::Language::Normalizer::Rtl < Base
      # Subclasses: ArabicNormalizer, HebrewNormalizer, PersianNormalizer.
      # Each overrides normalize_word(word) to do NFC + script-specific
      # canonicalization.
    end

### Tokenizer flag

`Kotoshu::Language::Base#rtl?` already returns false for Latin and
true for Arabic (verify). Use this flag to:

1. Pick the right normalizer.
2. Tell the CLI batch reporter to align output RTL.
3. Tell the tokenizer to handle RTL marks (U+200E, U+200F, U+202A-E).

### RTL mark handling

RTL/LTR marks are zero-width characters that affect display. The
tokenizer should:

1. Strip marks before tokenizing (so they don't become "characters"
   in a word).
2. Preserve them in the source mapping (so the editor shows them
   correctly).

The document API (TODO 50) already supports this naturally: marks
live in the source between text nodes; text nodes themselves are
mark-free.

## Phases

### Phase 1 — Arabic normalizer
- New `lib/kotoshu/language/normalizers/arabic.rb`.
- NFC + presentation-form canonicalization + optional diacritic strip.
- Specs with the existing Arabic fixtures in `data/ar/`.

### Phase 2 — Arabic tokenizer + dictionary integration
- Verify `languages/ar/language.rb` uses the new normalizer.
- Wire Arabic into the `Language::Registry` and the spell-checker
  pipeline.
- Specs with a small Arabic word list.

### Phase 3 — Hebrew + Persian normalizers
- Same shape as Arabic; different canonicalization rules.
- Specs per language.

### Phase 4 — RTL-aware display in CLI
- `cli/display_formatter.rb` aligns error context RTL when the
  detected language is RTL.
- `cli/batch_reporter.rb` aligns suggestions RTL.

## Acceptance criteria

- [ ] Arabic text is normalized identically regardless of input form
      (presentation form vs base form).
- [ ] `kotoshu check ARABIC_FILE` reports errors with correct source
      positions, RTL-aligned context.
- [ ] Same for Hebrew and Persian.
- [ ] The pre-existing `spec/integrational/fixtures/right_to_left_mark.*`
      fixtures pass.
- [ ] Full suite stays green.

## Dependencies

- **Blocked by:** TODO 50 (document API for source positions).
- **Blocks:** nothing.
