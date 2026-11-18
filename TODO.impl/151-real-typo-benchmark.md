# 151 — Real-typo benchmark (the honest second gate for suggestions)

## Thesis
The frozen nonword split (en.suggest2-nonword, 2000 pairs) is synthetic
(MULTYPO classes). The GitHub Typo Corpus word-level extraction (38,538
real human corrections, already extracted at /tmp/gtc_word_pairs.json
from the chirunder HF mirror of mhagiwara/github-typo-corpus, MIT) gives
a REAL-typo benchmark. Tonight's learned-prior rejection proved synthetic
and real distributions differ — the field needs both.

## Build
- [ ] Dedup + stratify 38.5k pairs → eval/realword/en.github-typo.json
      (v2-synthetic spec format: typo/correction/weight/class=op)
- [ ] score(): top-1/3/5 with eval/nonword_bench.rb (works as-is)
- [ ] Baselines: shipped engine (main 87.5 on synthetic) + quill-equivalent
      if available; record per-op-class breakdown
- [ ] Freeze (this split is REAL data — license MIT, attribution in the file)

## Then
- [ ] Confusion-matrix channel weights TUNED ON this benchmark (the
      synthetic-split transfer failed; real→real should not)
- [ ] Target: beat quill's 95.2-equivalent on its real-typo set

## Status
- [x] benchmark built (eval/realword/en.github-typo.json, 2,000 pairs,
      stratified 400/op: transpose substitution deletion insertion other;
      MIT attribution in-file)
- [x] baselines recorded (2026-11-19, shipped main via
      eval/nonword_bench.rb): **top-1 50.30 / top-3 57.20 / top-5 59.05**
      — vs 87.5 on the synthetic split. Per-class top-1: transpose 76.2,
      deletion 67.2, insertion 53.2, substitution 37.2, dist-2 other 17.5.
      THE SYNTHETIC NUMBER WAS HIDING A ~37PT REAL-WORLD GAP; substitution
      and dist-2 are the two weak fronts (the confusion-matrix lever now
      has a concrete target).
- [ ] channel iteration (substitution-pair weights first)
- [ ] dist-2 handling (the 17.5% class)
