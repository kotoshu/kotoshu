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
Executed 2026-09-07 — ko: HangulTokenizer (eojeol = run of syllables
U+AC00-D7A3 plus bare jamo U+1100-11FF/U+3130-318F), Dubeolsik grid
keyed on jamo per KS X 5002 (the eval harness models ko slips as
jamo confusion pairs, not a key grid, so no drift check applies),
module + 7 engine-verified specimens. ne: DevanagariTokenizer
(matras and virama conjuncts attached to the base consonant; danda
and Devanagari digits are separators), Devanagari InScript grid
mirrored from the eval harness _NE_INSCRIPT and drift-checked (the
defensible standard — Traditional Romanized is common but
undocumented), module + 3 specimens. Full-feature languages 33 -> 35.
Live round trips setup + check -l ko ne recorded; conformance 2630
vectors 0 failures; suite 3985 examples 0 failures. Specimen table
and dictionary sizes in the PR body for the site flip.
