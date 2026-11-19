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
- [x] train — COMPLETE 2026-11-19 (r1 = s1 4ep + s2 2ep on 2.52M rows,
      ~20 h200 windows through the storage/preemption gauntlet; bucket-vol
      anchors held every window)
- [x] package + parity — both variants on gec-artifacts (en/ +
      en-mega3r-fused/; note: the "fused" package is actually plain
      r1s2/final — the VOL_CKPT fuse path packages as-is; true fusion
      needs both stage finals hub-side, parked as a +~0.5pt upgrade
      experiment)
- [x] CoNLL-14 gate — **F0.5 0.5346 (P 0.581 R 0.406)** official M²,
      full set, training-faithful HF-tokenizer decode (scripts/decode_ort_py.py —
      the gem ByteBpe DIVERGES on multi-word encodes; python is the gate
      instrument for roberta-family artifacts)
- [x] publish decision — **PUBLISHED kotoshu/grammar-en v0.2.0-mega
      (0.5346 ≥ 0.522 bar; +1.3pt over penta, 3.2× LanguageTool)**
Rounds 2-3 continuation (+~0.5pt ru-law upside) = the next lever, fired
from the bucket r1s2/final anchor when queued.
