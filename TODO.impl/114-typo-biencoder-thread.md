# Plan 114 — The typo bi-encoder thread (bake-off follow-up)

## Why
Bake-off candidate C (0.5 MB char-BiGRU, 5.2 ms/suggest) beat the FULL
tier on repo-clean en/de pairs - the only successor that did. It needs:
non-en training data, a bigger clean bench, and a top-1 story.

## Work (models repo)
1. Extend training data beyond en (de ru es typo corpora; synth via the
   existing generator where corpora are thin).
2. Grow the repo-clean bench (target 2000+ pairs/lang); freeze as the
   C-benchmark.
3. Train v2; measure against fastText tiers on the same bench; ship as
   an OPT-IN registry resource only if it wins en+de clearly and degrades
   nowhere - reject honestly otherwise.

## Status
Executed 2026-09-09 — models PR #27 merged. VERDICT: REJECT, honest on
data; fastText tiers stay, no registry change, no tag. Frozen C-benchmark:
en 2509 real repo-clean pairs (target 2000+ met with real data only),
de/ru/es real clean pairs are 14/27/20 — the corpus holds only 212/551/186
unique pairs for those languages — plus a labeled 2000-pair noise.py synth
component per language, disjoint from all training sources. C v2 (same
0.481 MB architecture, training data the one changed variable) beats the
full tier on 2509 real unseen en pairs (+7.5 pp top-5, CI +5.9 to +9.1)
and fixed the top-1 gap (0.128 vs 0.103), but fails the pre-declared rule:
de real clears no paired CI at n=14, and es real regresses 10 pp top-5 at
n=20 (three independent es slices agree). Synth dominance (+40 to +48 pp)
is generator-domain and does not transfer to real es. Surviving thread for
a future plan: the C-retrieve + fastText-rescore hybrid beats the full
tier top-1 and top-5 on all four real components, but needs the
per-language vocab matrix cost priced and a real es/de typo corpus.
Full ladder: models eval/reports/biencoder-v2.md.
