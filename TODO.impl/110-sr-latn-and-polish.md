# Plan 110 — sr-Latn wiring and the long-tail polish list

## Why
Plan 107 wired nn and deferred sr-Latn (the Latin script variant of Serbian)
as follow-up. With the basic tier live, this is the last named language gap
in the corpus; everything after it is small-polish.

## Work (gem repo)
1. sr-Latn: register as a full-feature module reusing the Serbian dictionary
   with the Latin tokenizer + the Croatian/Slovenian QWERTZ grid (the
   scripts share the Latin layout), or map sr-Latn -> the staged sr-Latn
   dictionary if one exists in the manifest — follow the data, document the
   choice. Specimens engine-verified.
2. Polish sweep: any spellcheck_word_regex script set lacking a staged
   language (inventory + one-line table in the PR body); README language
   table refresh to the 35+ tiers.
3. Frequency-list inventory (no sourcing): list which staged languages have
   published frequency data wired vs not — record only, sourcing is a
   separate owner decision.

## Verification
Live setup + check -l sr-Latn round trip; suite green; conformance
untouched.

## Status
Pending
