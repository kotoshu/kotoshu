# 153 — Japanese standalone: real learner data (the pack is the ceiling)

## Verdicts on record (2026-11-17/18)
- ja-v11: tokenization mismatch (pack segmented by ja_segment_corpus.rb,
  serving uses suika) → gate 0.0039 copy-through
- ja-v12: suika-re-segmented, clean chain end-to-end → gate 0.0806 —
  mechanical fix worked, the PACK is the ceiling (68k synthetic
  corruptions of clean prose; 16.8% teacher yield)
- The cjk union's ja cell (0.309) remains ja's best home.

## The unlock
A real ja learner-error corpus. Candidates to license-scan:
- JT corpus (TodaysAbsent genius? — ja learner essay corpus w/ error
  annotations; academic license typically)
- Kaggle Japanese learner-error sets (JBLearner, lang-8 ja subset!)
  **lang-8 ja subset**: we HOLD lang-8 v2.0 (private, NAIST research-only
  terms — its ja portion could seed a pack under the SAME research terms
  the en cLang-8 used, but NOT commercial — the license fence must be
  re-checked per the ja terms before any use)
- CLE-style institutional asks (ALAGIN, NICT)

## Plan
1. [ ] License scan: lang-8 ja terms (Jaist/NAIST agreement re-read for
   the ja subset + derivative-pack + weights-release rights)
2. [ ] If research-only-only: decide with owner (train private, publish
   gates-only like en cLang-8, or skip)
3. [ ] Pack: re-segment with suika (the ur law), balanced classes on
   REAL errors (not synthetic corruptions)
4. [ ] Train → package → SEG.ja gate vs 0.309 union bar

## Status
- [ ] license scan
- [ ] owner decision
- [ ] pack
- [ ] train + gate
