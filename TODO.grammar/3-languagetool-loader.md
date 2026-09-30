# 3 — LanguageTool XML rule loader

LanguageTool's grammar rules are LGPL-2.1+ XML files. We write a
LOADER that parses their format and converts to our YAML rules —
users install the rule pack as a separate, opt-in download. This
gives instant access to 2,700+ rules without us writing them.

## The LanguageTool XML format

```xml
<rule id="EN_AVS_AN" name="Use 'an' instead of 'a' before a vowel">
  <pattern>
    <token>a</token>
    <token regexp="yes">[aeiou].*</token>
  </pattern>
  <message>Use 'an' before a word starting with a vowel.</message>
  <suggestion>an \1</suggestion>
  <example correction="an hour">It took <marker>a</marker> hour.</example>
</rule>
```

## The loader pipeline

1. Parse the XML → extract pattern (token sequence + constraints),
   message, suggestion template, examples
2. Convert token constraints to our YAML pattern DSL:
   - `<token>word</token>` → `{ word: word }`
   - `<token regexp="yes">pattern</token>` → `{ regex: pattern }`
   - `<token postag="VBZ"/>` → `{ pos: VERB_3SG }`
   - `<token min="0" max="1"/>` → `{ optional: true }`
   - `<exception>...</exception>` → `{ exception: [...] }`
   - `<and>`/`<or>` groups → nested constraint lists
3. Map LanguageTool POS tags to our reduced tagset
4. Emit YAML rules

## What NOT to port

- Disambiguation rules (require the full LT POS tagger)
- Chunk-level rules (require the chunker)
- Style rules that need sentence-tree analysis
- Rules for languages we don't serve

## Licensing

- Our LOADER is original code (no LGPL dependency)
- The rules are DATA loaded at runtime from a separate package
- Documented: `kotoshu rules install --source languagetool-en`
- The LanguageTool rule pack remains under LGPL; our engine under MIT

## Status: loader implemented on moxml + leptris (2026-09-30)

`Loaders::LanguageToolXml` + `Loaders::PosMapper` + `PatternRule` +
the recursive PosSequenceMatcher are implemented and speced
(spec/kotoshu/grammar/loaders/, scripts/lt_convert.rb). XML parsing
is strict Moxml with the leptris adapter — no lenient mode, no
preprocessing; invalid XML is rejected outright.

Pipeline state (real en grammar.xml, 8.3 MB, LT master):

| stage | state |
|---|---|
| strict leptris parse of the file | blocked by a leptris DTD bug — fixed on branch, leptris#1454 |
| entity expansion in content | internal-subset entities stay unexpanded (moxml/leptris gap, to report) |
| conversion with the fixes | 2,762/5,556 rules; recall 71.3%, FP 23.1% on LT's own examples |

Measured on the pre-fix REXML run (historical baseline): 3,512/5,556,
recall 60.1%, FP 20.5%. The gap is ~1,170 rules whose tokens/messages
use internal-subset entities (`&weekdays;`, `&it_s;`); they convert
once entity expansion lands upstream.

Semantics discovered from the real file (handled in the loader):
pattern-level and antipattern-level case_sensitive propagation,
exception scope="previous", SENT_END on the final token, LT 1-based
match numbers vs our 0-based templates, clitic tokenization
("Valentine's" → "Valentine" + "'s"), triggers_error examples.

Next levers after upstream lands:

1. inflected 1,163 total — expand via hunspell affixes (biggest
   lever; 1,976 inflected tokens, mostly plain words or alternations)
2. chunk rules ~320 — need LT chunk tags, no cheap mapping
3. empty_pattern ~121, repeat_range ~122, match_postag_transform ~108

The FP budget (TODO.grammar/2, <=2%) is not met by raw converted
rules: conversion must ship with the LT default=off flag honored and
a per-rule FP audit before any rule pack goes live. The example suite
is the audit instrument (it is LT's own CI test set).
