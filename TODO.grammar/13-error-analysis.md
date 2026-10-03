# 13 — Error-type analysis: where the remaining F0.5 lives

Measured 2026-10-03: penta (F0.5 0.419) against the official CoNLL-14
gold, per-edit span attribution (difflib opcodes vs gold M2 spans).
Recovery-validated reproduction: the rebuilt stack scores the penta
decode at exactly 0.4185.

## Headline

5,598 gold edits; penta touches 15.8% of edit spans. The three
biggest masses are ALL context-dependent:

| type | gold edits | penta hit | share of all misses |
|---|---|---|---|
| Wci (word choice/collocation) | 810 | 9% | 15.6% |
| ArtOrDet (article/determiner) | 756 | 19% | 12.9% |
| Mec (mechanics: spelling/punct/case) | 708 | 15% | 12.7% |
| Prep (preposition) | 589 | 21% | 9.9% |
| Nn (noun number) | 423 | 23% | 6.9% |
| SVA (subject-verb agreement) | 250 | **32%** | 3.6% |

Our strengths are exactly the morphological/agreement classes the
closed-class architecture was built for (SVA 32%, Nn 23%). The three
context masses — Wci + ArtOrDet + Prep = 2,155 edits, 38% of all
gold — are the distillation targets.

## Consequences

1. **The context classes resist pattern rules** — this closes the
   rules-expansion question with data: expanding rules in Wci/Prep
   would chase 38% of the gold mass with the wrong tool. Original
   rules stay targeted at deterministic classes only.
2. **Mec (708 edits) is partly an INTEGRATION gap, not a model gap**:
   spelling/punctuation live in the rules/spelling layer, while the
   benchmark decode runs the tagger alone. The shipped product runs
   both; the benchmark number under-reports the product.
3. **Distillation design (Experiment B)**: harvest the teacher's
   recall specifically for Wci/ArtOrDet/Prep — precision-filtered
   pairs in exactly those classes.
4. Mega (cLang-8) is the known lever for ArtOrDet+Prep+Vform (the
   cLang-8 distribution is rich in exactly those).

## Method

Gold: official-2014.combined.m2 typed edits (noop excluded). System
edits: difflib opcodes source->system-output, span-overlap matching.
Script inline in session; reproducible from
~/.cache/kotoshu-gec/ (durable — /tmp is banned).
