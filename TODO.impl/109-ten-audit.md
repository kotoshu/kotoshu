# Plan 109 — The 1.0 readiness audit

## Why
Adopters hesitate at 0.x. A 1.0 cut needs a frozen public surface and a
stated policy. The audit inventories what 1.0 would freeze and what it
would deprecate — it does NOT cut versions (owner decision).

## Work (gem repo docs/, analysis only)
1. Inventory the public surface: Ruby API (Kotoshu module functions,
   Spellchecker, Configuration, Tasks, validators), CLI flags, wasm JS
   surface (KotoshuWasm, loadModel/rerank/semanticSuggest/loadLid/
   detectLanguage), HTTP contract (openapi.yaml), action inputs, registry
   schema.
2. For each: stable / needs-deprecation-notice / internal-accidentally-
   public. Flag anything accidentally public that 1.0 should privatize.
3. Draft the stability policy (semver commitments, deprecation window,
   conformance vectors as the behavioral contract) as docs/STABILITY.md.
4. A 1.0 checklist: what must land first (nothing mechanical is known to
   block), what the release train looks like (gem+wasm+server together).

## Verification
Every inventory line cites the file that defines it; the deprecation list
reviewed against gemspec/exported constants.

## Status
Pending
