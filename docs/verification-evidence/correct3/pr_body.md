## Summary

Plan 91: two correctness fixes for non-ASCII users, found by the site-flip agent (plan 90 residues).

### Track A — Unicode word detection

`Spellchecker#word_char?` accepted only ASCII letters, so Greek and Ukrainian users could not check any text: every non-Latin word was silently invisible and `kotoshu check -l el` reported `0 words`.

Word extraction now follows the language being checked:

- `Tokenizer::Base#spellcheck_word_regex` — single-character regex for spell-check extraction. Base default is the historical ASCII set (letters + apostrophe), so tokenizers without an override keep their exact behavior.
- Overrides: Greek `[\p{Greek}']` (apostrophe stays in-word for elisions like `απ’`), Cyrillic `[\p{Cyrillic}']` (`Мар'яна` stays one word), Latin `[\p{Latin}']` (covers capitals like `Å`/`Ä` that the old `à-ÿ` range missed, plus Turkish `ı ğ ş İ`).
- Digits are never word characters, so number-adjacent splitting is unchanged.
- `Spellchecker` resolves the tokenizer from the resource bundle language first (the facade passes the global `Configuration` next to the resolved bundle, so the config default is the wrong source) and falls back to the `Language::Registry` language, then to ASCII. Wrong-script words stay invisible: Greek text under `-l en` extracts nothing.
- Languages without a script tokenizer (en uses the components whitespace tokenizer, de has no override yet) keep the ASCII behavior — guarded by specs.

### Track B — Swedish aff `RegexpError`

`Readers::AffReader` raised `RegexpError: unmatched close parenthesis` on the Swedish dictionary (dictionaries pin 1829a3e). Root cause: `COMPOUNDRULE )k` uses `)` itself as a flag character ("for adjectives: )k", "for verbs: >j" per the aff comments), but `CompoundRule` only escaped `)` when preceded by a non-operator character. A leading or post-operator `)` survived raw into `Regexp.new` and raised. The fix escapes every flag atom (`Regexp.escape`) while keeping `*`/`?` operators and `(...)` groups intact. The full sv dictionary (152,719 words) now loads and checks.

## Verification

- Full suite: `3696 examples, 0 failures, 27 pending` (13 new examples)
- Frozen conformance replay: `rake kotoshu:conformance:ruby` — 2630 vectors, 0 failures, byte-identical
- rubocop clean on all changed files
- End-to-end through the real CLI (setup + check, isolated cache, dictionaries from the pin):

| lang | correct sentence | bogus word |
|---|---|---|
| el | OK, 5 words, no errors | `θθξκζψθ` flagged |
| tr | OK, 5 words, no errors | `ğşxqzz` flagged |
| sv | OK, 7 words, no errors | `ÅÅxxqqz` flagged |
| it | OK, 5 words, no errors | `zzqqxvv` flagged |

Note: remote `kotoshu setup it/el/tr/sv` currently 404s because upstream `dictionaries` only ships `en/` under the `spelling/` URL layout — verified instead with `setup LANG --from` against dictionaries fetched from pin 1829a3e. That URL-layout gap is upstream content, not this PR.

RBS: added `spellcheck_word_regex` to the declared Greek/Cyrillic tokenizers. No version changes.
