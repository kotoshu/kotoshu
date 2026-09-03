# 72 — Model2Vec Evaluation (adopt-later C1 decision)

From [68-sota-adoption.md](68-sota-adoption.md) item C1. Model2Vec /
Potion distilled static embeddings: ~30 MB, ~500× faster than fastText,
beats other statics on MTEB
([repo](https://github.com/MinishLab/model2vec),
[fastText comparison](https://minish.ai/blog/2025-07-28-fasttext/)).
Word-keyed like ours — same OOV gap.

## Goal

Decide adopt/reject on DATA, using the corpus benchmark plan 69 built:
can a Potion-class static embedding beat our shipped full/fluency tiers
on the GitHub Typo Corpus top-1/5/20 hit rates, at comparable or
smaller size? License per model verified for redistribution (Potion
series is MIT, models distill from different teachers — record each
teacher's license).

## Tasks

1. `eval/model2vec_bench.py` — for each candidate model
   (potion-base-8M, potion-base-32M, potion-mini-8M and one
   fastText-comparable MTEB-strong variant): load via HF hub (network,
   never in CI), map our corpus pair words, compute the same top-k hit
   rates as `corpus_bench.py`, per language.
2. Report `eval/reports/model2vec.{lang}.json`: candidate vs
   full/fluency/mini hit rates + model size + license chain.
3. Decision rule (pre-declared): adopt only if a candidate beats
   **fluency** top-5 on ≥ 5 of 9 languages at ≤ 20 MB with a clean
   license chain; otherwise record reject with numbers.
4. If adopt: a separate plan supersedes this one for integration
   (registry entries, gem resolver) — this plan only decides.

## Acceptance

- Reports for all 9 languages × candidates, committed; corpora never
  committed; decisions traceable to numbers.

## Status

**Evaluated (2026-09-03): REJECT on data** (models PR #7). The only
size-compliant candidate (potion-base-2M, 7.6 MB) wins 0/9 languages
(en top-5 0.241 vs fluency 0.252); the 129 MB potion-base-32M manages
one marginal English edge and loses everywhere else. Structural
blocker: Potion is English-only WordPiece - eight of nine languages
are not coverable. Licenses were clean; the rejection is on merit.
Side-result: our fastText tiers beat the current static-embedding SOTA
on our own task. C1 closed - revisit only if a genuinely multilingual
static model appears under the size cap.
