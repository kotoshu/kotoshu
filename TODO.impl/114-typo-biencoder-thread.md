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
Pending
