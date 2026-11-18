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
- [x] channel iteration (substitution-pair weights first) — VERDICT
      2026-11-18: CLOSED as a naive additive lever. The GTC-derived
      confusion table (en.typo-confusions.json, 20,170 sub ops, eval
      excluded) re-ranks the frozen top-5 slates: substitution class
      +6.8pt at λ2 (37.2→44.0) but deletion −2.4 / insertion −3.0
      demotion (non-substitution candidates carry no boost → relative
      demotion) = net top-1 FLAT (50.30→50.25); λ5 = net LOSS (48.2).
      Synthetic +0.75 at λ3. Prototype: eval/realword/rerank_proto.py.
      Remaining variant: full op-aware channel (per-op priors for
      ins/del/trans + pair confusions + frequency prior, same form as
      the kotoshu-rs noisy-channel port) — but that branch already
      scored 86.2 < 87.5 main on synthetic (two strikes); parked unless
      a real-split-first design shows ≥3pt.
- [ ] dist-2 handling — ROOT CONSTRAINT FOUND 2026-11-18: it is a
      CANDIDATE-GENERATION ceiling, not ranking: gold is in the top-5
      for only 28.0% of the dist-2 class (17.5 top-1). Re-ranking
      cannot recover what retrieval never surfaced. Next lever: enable
      the typo-biencoder layer (native ext, opt-in — the bench measured
      the traditional path only) and re-baseline the real split.
