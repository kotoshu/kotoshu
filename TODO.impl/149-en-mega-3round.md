# 149 — English 3-round MEGA retrain (the 0.52 → 0.55+ lever)

## Thesis
The 2.52M-row mega corpus (mega_c4_distill_2646k.jsonl, STAGED since
2026-10-03) was trained once under the old 8-epoch flat recipe (0.487 —
recall trade). The 3-round schedule (s1 vanilla 4ep → s2 KEEP-weighted
2ep at LR/10) has since won on ru (0.422), ur (0.640), and cjk v11
(0.661/0.788) — it has never touched the mega corpus.

## Run
- data: `data/mega_c4_distill_2646k.jsonl` (gec-training-private)
- base: roberta-base, batch 16, bf16 off (roberta trains fp32)
- rounds: 3, RESUME_SAVE_EVERY=20000, GEC_CKPT_DIR/GEC_DATA_IN fresh
- ckpt: kotoshu/gec-ckpt-en-mega3r
- ETA: ~5-6h clean h200 (2.52M × 6ep ÷ 16 batch ≈ 946k steps... TOO BIG:
  cap rounds to s1-only pass 1 (4ep ≈ 630k steps ≈ 8-9h) or subsample.
  DECISION: rounds=1 first (s1+s2 = 945k steps ≈ 13h clean) — ru law says
  3-round but at mega scale even 1-round untrained-grade is the rung;
  measure, then round 2/3 continue from banked finals.

## Gate
CoNLL-14 full set, official M2 scorer, --max_unchanged_words 2,
from the packaged artifact (gec-artifacts en-mega3r-r1/). Compare against
0.522 (penta published) and 0.487 (old mega recipe).

## Status
- [x] corpus staged
- [ ] train
- [ ] package + parity
- [ ] CoNLL-14 gate
- [ ] publish decision (replaces penta only if ≥ 0.522)
