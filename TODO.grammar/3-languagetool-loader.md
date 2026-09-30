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
EOF
echo "file 3 written"