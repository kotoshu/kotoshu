# Plan 112 — Deployability and CI gating

## Work (kotoshu-rs; site rides a follow-up)
1. Prebuilt worker on npm: @kotoshu/worker exposing the playground's
   engine worker (load/check/suggest-batch/semantic/detect protocol) so
   JS users embed the engine without reimplementing the worker; versioned
   with the wasm package.
2. CI latency gate: the multi-language sweep bench (rs PR #23 harness)
   runs on CI with budgets (en < 120 ms, pt < 700 ms avg) failing red.
3. Wasm memory ceiling test: dict + mini tier + buckets resident under a
   stated budget per language class.
4. Language pack (design note, owner decision): one fetch for
   dict+tier+buckets — additive registry field sketch in the PR body.

## Verification
Node smoke for the worker package; budgets tuned to measured p50s, not
aspirations; all existing CI green.

## Status
Pending
