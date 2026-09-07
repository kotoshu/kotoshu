# Plan 108 — Korean and Nepali: the last big-population languages

## Why
ko (~82M) and ne (~16M) were deferred from batch 3 because Hangul jamo
input and Devanagari conjuncts need ja-style tokenizer treatment. They are
the largest populations without full-feature support; both have staged
dictionaries and models.

## Work (gem repo; sequenced AFTER plan 107 merges — same area)
1. ko: Hangul tokenizer (syllable-block aware, jamo-level word regex so
   check extracts real eojeol), Korean keyboard grid (Dubeolsik 2-set),
   module + specimens engine-verified.
2. ne: Devanagari tokenizer (matras and conjuncts stay attached to the
   base consonant — the Unicode grapheme rules the script needs), Roman
   keyboard fallback or a Nepali traditional grid if defensibly sourced,
   module + specimens.
3. AVAILABLE_LANGUAGES + site-flip deliverables (specimen table, sizes).

## Verification
Same discipline as batch 3: every specimen engine-verified through
correct?/suggest; RTL/complex-script sentence round trips through
Kotoshu.check; suite green.

## Status
Pending
