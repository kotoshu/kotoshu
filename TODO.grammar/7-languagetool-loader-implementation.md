# 7 — LanguageTool XML loader implementation

## Approach: loader, not redistribution

We write a parser for LanguageTool's XML rule format. Users install
the rule pack separately. Our engine stays under our license; the LT
rules stay under LGPL. This is the cleanest legal path.

## The XML format (what we parse)

```xml
<rule id="EN_AVS_AN" name="Use 'an' before vowel">
  <pattern case_sensitive="no">
    <token>a</token>
    <token regexp="yes">(?-i)[aeiouAEIOU].*</token>
  </pattern>
  <message>Use 'an' instead of 'a'.</message>
  <suggestion>an \1</suggestion>
  <example correction="an hour">It took <marker>a</marker> hour.</example>
</rule>
```

## The loader pipeline

1. Parse the XML (Nokogiri in Ruby, quick-xml in Rust, DOMParser in TS)
2. Convert token constraints to our YAML pattern DSL:
   - `<token>word</token>` → `{word: "word"}`
   - `<token regexp="yes">pat</token>` → `{regex: "pat"}`
   - `<token postag="VBZ"/>` → `{pos: VERB_3SG}`
   - `<token min="0" max="1"/>` → `{optional: true}`
   - `<exception postag="DT"/>` → `{exception_pos: DET}`
   - `<and>`/`<or>` → nested constraint lists
3. Map LT POS tags → our tagset
4. Emit YAML rules loadable by our engine

## POS tag mapping (LT Penn Treebank → our 17-tag set)

| LT tag | our tag |
|--------|---------|
| NN, NNS | NOUN, PLUR_NOUN |
| NNP, NNPS | PROPER_NOUN |
| VB | VERB_BASE |
| VBZ, VBP (3sg) | VERB_3SG |
| VBD | VERB_PAST |
| VBG | VERB_ING |
| VBN | VERB_PARTICIPLE |
| JJ, JJR, JJS | ADJ |
| RB, RBR, RBS | ADV |
| IN | PREP |
| DT, PDT | DET |
| PRP (3sg), PRP$ | PRON_3SG |
| PRP (plural) | PRON_PLURAL |
| MD | MODAL |
| CC | CONJ |
| CD | NUMBER |

Rules using tags outside this mapping get skipped (with a count).

## What we skip

- Disambiguation rules (need LT's full tagger)
- Chunk-level rules (need their chunker)
- Rules requiring LT's internal Java API
- Rules for languages we don't serve

## The CLI

```
kotoshu rules install languagetool-en
kotoshu rules list --source languagetool
kotoshu rules info EN_AVS_AN
```

The install downloads from languagetool.org (or a mirror), converts,
and caches. The converted rules stay LGPL (marked in the metadata).

## File layout

```
lib/kotoshu/grammar/loaders/
  languagetool_xml.rb    # the parser
  pos_mapper.rb          # LT → our tagset
spec/kotoshu/grammar/loaders/
  languagetool_xml_spec.rb
```
