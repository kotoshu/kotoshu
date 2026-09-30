# 4 — Multilingual rules + the 12-language target

The LanguageTool gaps analysis (docs/KOTOSHU_LANGUAGETOOL_GAPS.md)
targets 12 languages. Our priority languages, with the grammar
rules that matter most for standards documents:

## Tier 1 (the wave-2 measured languages)

| lang | top grammar errors for standards | feasibility |
|---|---|---|
| en | agreement, confusion, punctuation, wordiness | HIGH — rules + POS tagger |
| de | adjective declension, case, compound separation | MEDIUM — needs morphology |
| es | ser/estar, subjunctive, gender agreement | MEDIUM — needs morphology |
| fr | accord, subjunctive, liaison | MEDIUM |
| ru | case declension, aspect, verbal government | HARD — needs full morphology |
| zh | measure words, aspect markers, formal register | MEDIUM — needs word segmentation |
| ja | particles, keigo levels, T-V distinction | HARD — needs morphological analyzer |
| ko | particles, honorifics, verb endings | HARD |
| ar | i'rab (case vowels), agreement, word order | MEDIUM (the vowelless normalization helps) |
| vi | classifiers, aspect particles, tone consistency | LOW — mostly lexical |
| el | article agreement, case, subjunctive | MEDIUM |
| pt | ser/estar, clitics, gender agreement | MEDIUM |

## The realistic scope

**English first** (the highest-value + lowest-effort): 100–150 rules
covering agreement, confusion, punctuation, and style. The rules are
data (YAML), so they ship without engine changes.

**German/Spanish/French second** (after the POS tagger generalizes):
agreement + gender + verb conjugation errors. Needs the POS tagger
extended with per-language suffix rules.

**The rest third**: the morphological analysis needed for Slavic/
CJK/Arabic grammar checking is a separate arc (each language needs
a lemmatizer or a neural tagger).

## The standards-specific rules (unique to Metanorma)

Beyond general grammar, the standards domain has its own correctness
patterns (metanorma's rules could include these):

- "shall" vs "should" vs "may" (requirements language — IEC/ISO
  directives have strict usage)
- Abbreviation consistency (first use full, subsequent abbreviated)
- Cross-reference format consistency
- Unit formatting (SI, non-SI)
- Terminology consistency (same concept = same term throughout)

These are Metanorma-domain rules, not general grammar — but they
ride the same rule engine.
EOF
echo "file 4 written"