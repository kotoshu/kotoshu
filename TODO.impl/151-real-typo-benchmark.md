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
- [ ] benchmark built
- [ ] baselines recorded
- [ ] channel iteration
