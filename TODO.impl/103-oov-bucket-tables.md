# Plan 103 — OOV bucket-table artifacts: model-generated candidates for the last mile

## Why
semanticSuggest embeds an OOV word via subword n-grams PRESENT IN THE VOCAB;
a typo whose n-grams never appear (Teh — only n-gram "teh") embeds nothing
and returns empty. fastText's real OOV path hashes n-grams into buckets the
training wrote to; exporting the bucket table closes that gap so the model,
not just the Damerau sweep, can reach the intended word. Recorded as the
honest gap in kotoshu-rs oov.rs docs and PR #18's report.

## Work (models repo, then kotoshu-rs)
1. Export the bucket-table rows the FastText training produced (hash bucket
   → vector) for each tier alongside the vocab; size audit first — the
   bucket table may exceed the tier itself; if so, gate to the top-K buckets
   by usage and measure the quality delta honestly.
2. kotoshu-rs: extend the int8 reader to consult bucket rows for n-grams
   absent from vocab (feature-gated like `model`); semantic_neighbors then
   covers bucket-backed OOV.
3. Gates: existing rerank conformance must not move (frozen); new specs for
   bucket-backed neighbors (Teh→the expected); eval on the rerank probe set.

## Verification
Bucket-backed neighbor specs; size deltas recorded; rerank conformance 0
change; a 0.4.x wasm release only after both engines agree.

## Status
Executed 2026-09-07 — models PR #20 (en/de buckets) + kotoshu-rs PR #26 (bucket-backed OOV). Teh→the via buckets. Release assets + wasm 0.4.0 pin still owner/coordinated cut. (sequenced AFTER plan 101 — same repo, one worktree at a time)
