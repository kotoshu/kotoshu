# 90 — Gem correctness residues found by the site flip

> Found 2026-09-05 while engine-verifying the 13 new specimen pages.
> The available-languages gate (the worst of the three) was fixed the
> same night in passing; the two below remain.

## Fixed same-night (context)

`LanguageCache::AVAILABLE_LANGUAGES` hardcoded the original six, so
`kotoshu setup it` (and every other new module language) 404'd at the
pin — blocking the entire wave-2 module work at the last step. Now the
19 module languages, with a comment explaining the module-boundary
rule (staged dictionaries join when their module lands).

## Remaining

### A — AffReader crashes on the Swedish aff

`Readers::AffReader` raises `RegexpError: unmatched close parenthesis`
on the staged Swedish `.aff` (dictionaries pin 1829a3e). Verified by
the site agent: the file loads fine under hunspell 1.7.2, so this is
our parser, not the data. Likely an unescaped `)` inside a condition
or MAP/BREAK pattern reaching `Regexp.new` without escaping. Fix the
escaping site (not the fixture); spec with the real sv aff slice.

### B — Spellchecker word detection is ASCII-only

`Spellchecker#word_char?` (and whatever tokenizer feeds it) treats
only ASCII as word characters, so el/uk (and any non-Latin script)
words are not extracted on the CLI path — the site agent verified the
new Greek/Ukrainian specimens via dictionary lookup because the CLI
path could not see the words at all. Extend word-char detection to
Unicode letters (per-language script knowledge already exists in the
tokenizers); guard behavior with specs on el/uk/ja text and confirm no
regression on the ASCII languages (the whole conformance corpus is
ASCII — it must stay byte-identical).

## Owner gates

None.

## Status

**Pending.**
