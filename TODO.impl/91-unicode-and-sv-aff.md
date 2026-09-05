# 91 — Executes plan 90: Unicode word detection + the Swedish aff parser

## Track A — Unicode word detection (the bigger one)

`Spellchecker#word_char?` (spellchecker.rb:313) accepts only ASCII
letters, so Greek/Ukrainian/any non-Latin script words are never
extracted on the CLI path — el/uk users cannot use the checker at all
(found by the site-flip agent; specimens could only be verified via
raw dictionary lookup).

- Extend word-char detection to Unicode letters. The per-language
  tokenizers (wave-2 added Greek/Cyrillic ones) already know their
  scripts — the fix should respect the language's tokenizer/script
  rather than widening a global ASCII set (wrong-script words must
  not suddenly become checkable).
- **Non-negotiable**: the frozen conformance corpus is ASCII — every
  vector must stay byte-identical. Guard with the full conformance
  run plus new el/uk/ja extraction specs.
- End-to-end verify: `echo "<greek typo>" | bundle exec exe/kotoshu
  check -l el` flags it; same for uk; en/de regression-clean.

## Track B — AffReader RegexpError on the Swedish aff

`Readers::AffReader` raises `RegexpError: unmatched close parenthesis`
on the staged Swedish .aff (pin 1829a3e); hunspell 1.7.2 loads it
fine. Find the unescaped-`)` site (likely condition/MAP/BREAK pattern
compilation) and fix the escaping — never the fixture. Spec with a
minimal slice of the real sv aff.

## Track C — setup end-to-end spot-check

After PR #127's gate widening, run `kotoshu setup` + check for it,
el, tr, sv (sv will hit Track B until fixed — fix first). Record
which languages verified end-to-end through the CLI.

## Status

**Implemented (2026-09-05, gem PR #130 + residue PR #131).** Track B:
COMPOUNDRULE )k - the sv aff uses ) as a flag char; flag atoms now
Regexp.escape'd (full 152k-word sv dictionary loads). Track A:
Tokenizer::Base#spellcheck_word_regex with Greek/Cyrillic/Latin
overrides, digits excluded, ASCII default byte-identical (2630 frozen
vectors 0 failures); plus the bundle-language-priority fix that made
`check -l el` extract zero words. Track C: remote setup for staged
languages was the LAST gap - PR #131 added the flat-layout fallback
(verified live: setup it + check -l it, probva -> prova). el/tr/sv/it
all verified end-to-end. Suite 3701/0/27.
