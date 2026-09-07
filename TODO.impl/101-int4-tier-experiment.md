# Plan 101 — int4 tier experiment (models repo), eval-gated

## Why
The tier recipe settled at int8 (rank_corr 0.9999, near-lossless) after SVD
failed its gates. int4 halves the bytes again — mini ~1.5 MB, fluency ~8 MB —
which changes browser adoption math for the wasm playground. It was named in
the original kotoshu-rs TODO (B1) but never run through the gates.

## Work (models repo)
1. Quantization pass: per-row int4 (packed nibbles) + fp16 scale, over the
   same vocab cuts as fluency/mini.
2. The existing eval gates unchanged and unweakened: rank correlation vs
   full float32 on the keyboard-aware eval; accept only if rank_corr within
   0.001 of int8's and top-1 agreement holds on the probe-limited languages.
3. If gates pass: registry v1.4.0 adding the int4 variants as NEW resources
   (`{lang}/mini4`? or a field) — additive, never replacing; mirror with
   ACAO:* like v1.2.1+. If gates fail: record the numbers as the verdict
   (the SVD precedent — measured, not assumed).
4. ONNX reader side (kotoshu-rs) only if the gates pass.

## Verification
Gates table per language; byte sizes; the release registry byte-identical to
the committed one; no existing tier URLs change.

## Status
Executed 2026-09-07 — REJECTED on data (models PR #17, merged). int4-per-row
(one fp16 scale, packed nibbles) over 8 languages: rank_corr deltas -0.0146
to -0.0199 vs int8 (15-20x outside the 0.001 window), top-1 fails on 8/8
fluency4 and 2/8 mini4. Sizes halve (mini4 1.52 MB, fluency4 7.60 MB) but
accuracy does not hold. With the earlier group-128/64/32 sweep the scale
ladder is measured end to end — int8-per-row stands final. Registry
untouched; evidence in models eval/reports/.
