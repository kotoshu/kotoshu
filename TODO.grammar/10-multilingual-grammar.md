# 10 — Multilingual grammar: the 12-language path

## Per-language grammar feasibility

| lang | LT rules | our rules needed | grammar classes | difficulty |
|---|---|---|---|---|
| en | 2,700 | 150 original + LT | agreement, confusion, punctuation | ✅ foundation done |
| de | 2,000 | 50 + LT | adjective declension, case | MEDIUM |
| es | 1,500 | 50 + LT | ser/estar, gender, subjunctive | MEDIUM |
| fr | 1,500 | 50 + LT | accord, subjunctive | MEDIUM |
| it | 1,200 | 30 + LT | agreement, prepositions | MEDIUM |
| nl | 1,000 | 30 + LT | word order (V2), articles | MEDIUM |
| pt | 1,000 | 30 + LT | ser/estar, clitics | MEDIUM |
| ru | 800 | 50 + LT | case declension, aspect | HARD |
| pl | 800 | 30 + LT | case, gender | HARD |
| el | 200 | 30 + LT | article agreement, case | MEDIUM |
| ar | 100 | 30 | i'rab, agreement, word order | MEDIUM (our P0 helps) |
| vi | 10 | 20 | classifiers, aspect | LOW (mostly lexical) |
| ja | 100 | 20 | particles, register | HARD |
| ko | 50 | 20 | particles, honorifics | HARD |
| zh×3 | 50 | 20 | measure words, register | HARD |

## The CJK/Arabic problem

LT is weak in CJK (ja/ko/zh) because these languages need:
- Word segmentation (ja, zh) before rule matching
- Morphological analysis (ko particle analysis, ja keigo)
- Different grammar model (topic-prominent vs subject-prominent)

Our advantage: we already have the fasttext models for all 16
languages, which handle the statistical layer. The CJK grammar rules
need to be original (LT has almost nothing), and they need
segmentation (which our suika integration provides for ja).

## Priority order

1. **en** (done: 20 rules, +130 to author)
2. **de** (LT strong + our list identity) — adjective declension is
   the highest-value class for German standards documents
3. **es, fr** (LT strong + widespread standards use)
4. **ru, pl, pt, it, nl** (LT available)
5. **ar** (LT limited but our vowelless normalization helps)
6. **el** (LT limited)
7. **vi** (mostly lexical, minimal grammar rules needed)
8. **ja, ko, zh×3** (need original rules + segmentation)
