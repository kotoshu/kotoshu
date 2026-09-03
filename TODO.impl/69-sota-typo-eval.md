# 69 — Keyboard-Aware Typo Eval + Real-Typo Corpus Benchmark

Executes the "adopt now" items A1 + A2 of
[68-sota-adoption.md](68-sota-adoption.md). Lands in
`models-fasttext-onnx` (`eval/`), feeding the same gate machinery as
plan 06.

## Goal

1. Replace the eval harness's ASCII-lowercase-only typo generator with
   a **keyboard-layout-aware multilingual noise model** (MULTYPO-style,
   [repo](https://github.com/cisnlp/multypo),
   [arxiv 2005.01158](https://arxiv.org/html/2005.01158v1)):
   QWERTY/QWERTZ/AZERTY/JCUKEN neighbor-weighted slips for
   de/en/es/fr/pt/ru, umlaut/eszett keys for de, Cyrillic neighbors for
   ru; for ja/ko/zh a visual/phonetic character-confusion model
   (homoglyph + stroke-similar substitutions) replaces key-adjacency.
   All deterministic (seeded), in-vocab typos only (the metric requires
   both models to embed the typo).
2. Add the **GitHub Typo Corpus**
   ([repo](https://github.com/mhagiwara/github-typo-corpus),
   [LREC 2020](https://aclanthology.org/2020.lrec-1.835/); 350k+ real
   human typo corrections, 15+ languages, MIT) as a real-world
   embedding-side benchmark: for corpus (typo → correction) pairs in
   our 9 languages where both words are in-vocab, measure how the
   cosine-to-typo ranking places the correction, per tier. Report-only
   (no gate) in v1 — it measures the full correction pipeline only
   after kotoshu-rs conformance vectors exist (plan 67 M3).

## Tasks

1. `eval/noise.py` — per-language deterministic typo generator:
   layout-driven for Latin/Cyrillic scripts (the gem's own
   `keyboard/layouts` are the layout source of truth — mirror them),
   character-confusion for CJK. Same RNG discipline as `run_eval.py`
   (`default_rng([seed, crc32(lang)])`).
2. Wire into `run_eval.top1_agreement_metric` as the typo source;
   **gates unchanged** — they get honestly harder. Ladders climb if a
   language now misses (record attempts as before).
3. `scripts/fetch_corpus.py` — download-once the GitHub Typo Corpus
   release into `eval/corpora/` (gitignored), verify checksum, extract
   per-language pairs.
4. `eval/corpus_bench.py` — the benchmark runner →
   `eval/reports/corpus.{lang}.json` (committed): pairs evaluated,
   correction-in-top-1/5/20 rates per tier vs full.
5. Regenerate all 18 tier reports with the new typo model; commit the
   new reports + report the gate deltas in the PR.

## Acceptance

- `run_eval.py` produces identical results for identical inputs
  (determinism test); non-Latin languages get realistic typos
  (spot-check list in the PR).
- All 9×2 tier reports regenerated; any ladder climbs recorded.
- `corpus_bench.py` runs offline after `fetch_corpus.py`; reports
  committed; corpus itself never committed (size + license header
  attribution in the report JSON).

## Dependencies

- Feeds plan 06's gate machinery; blocks nothing.
- Owner gate: none (corpus is MIT; no new model distribution).

## Status

**Implemented (2026-09-03, models PR #5 merged).** eval/noise.py ships
layout-neighbor slips (QWERTY/QWERTZ/AZERTY/JCUKEN mirrored from the
gem layouts, diacritics included), Hangul jamo decomposition and
curated CJK confusion sets, transposition fallback; deterministic. All
18 reports regenerated under the harder typos - gates pass, no ladder
climbs; de/fluency corrected to 50k (the 60k was small-n noise).
GitHub Typo Corpus bench live (official S3 dead; Wayback snapshot with
self-pinned sha256); top-5 full-tier baselines 0.13 (ja) - 0.60 (ko).
Part of release v1.0.1.
