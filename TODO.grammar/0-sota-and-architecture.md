# Grammar checking: architecture, SOTA, and the kotoshu plan

## The GEC (Grammatical Error Correction) landscape 2022–2026

From the literature (arxiv, BEA/WMT shared tasks, LanguageTool docs):

| approach | speed | accuracy | client-side | explainable | SOTA ref |
|---|---|---|---|---|---|
| Rule-based (LanguageTool) | ✅ ms | good for rules it has | ✅ | ✅ | deployed 20+ yrs |
| GECToR tagger (2020) | ✅ ~50ms | M2 56–65 | int8-quantizable | ❌ | Omelianchuk+ 2020 |
| T5/BART seq2seq | ❌ ~500ms | M2 70–78 | ❌ too large | ❌ | Rothe+ 2021, Katinskaia+ 2024 |
| LLM (GPT-4, Claude) | ❌ seconds | high | ❌ API-only | ❌ | Davis+ 2024 |
| Distilled int8 ONNX | ~100–200ms | M2 55–62 | ✅ | ❌ | our target (2025) |

## LanguageTool's actual architecture

1. **Tokenization + POS tagging** (their own tagger, per-language)
2. **Chunking** (phrase-boundary detection)
3. **Rule evaluation** over the annotated text:
   - Simple word-list rules (regex/word match)
   - POS-tag pattern rules (e.g. `<token postag="VBZ"/><token postag="VBN"/>`)
   - Disambiguation rules (resolve POS ambiguity before rule eval)
4. **n-gram confusion model** (realword errors — our realword model)
5. ~2,700 en rules, 30+ languages, XML format

## The kotoshu architecture (three layers)

```
Layer 1: Rule engine (exists — 8 matchers, YAML rules)
Layer 2: POS-aware rules (needs POS tagging + agreement patterns)
Layer 3: Statistical (fasttext n-gram context — our existing models)
Layer 4: Neural tagger (GECToR-style, ONNX int8, <100 MB) — future
```

## What LanguageTool has that we don't (the gap analysis)

- POS tagger + disambiguator
- ~2,700 en grammar rules (pattern + POS + chunk)
- 30+ language packs
- XML rule format (with regex, POS tags, exceptions, negations)
- n-gram model for realword (we have the equivalent: fasttext)

## What we have that LanguageTool doesn't

- Realword context model (fasttext — ar 26.5, de 17.0)
- Cross-script retrieval (mrhb → مرحبا)
- Variant-pure zh (no script-mixed lists)
- 3-API support (Ruby/Rust/TS)
- Fast test infrastructure (16-language frozen splits)

## The realistic path to parity

1. Write a **LanguageTool XML rule loader** — parse their format, convert
   to our YAML rules. Users install the rule pack separately.
2. Write a **lightweight POS tagger** — rule-based (suffix + context),
   no neural model needed for the top 20 agreement patterns.
3. Author the **high-impact en rules** (~50–100 rules covering the
   80% of errors the top 20% of LanguageTool's rules catch).
4. Add **agreement checking** (subject-verb, pronoun-antecedent) using
   POS + fasttext context as a tiebreak.
5. Benchmark on **BEA-2019 / CoNLL-2014** test data against
   LanguageTool running on the same sentences.

## Licensing

- LanguageTool's rules are LGPL-2.1+ — loading their XML as data at
  runtime is permissible; the rules remain a separate download.
- Our own rules are original work under the project license.
- The POS tagger is original (rule-based, no external dependency).
EOF
echo written