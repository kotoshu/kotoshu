# Plan 113 — Language packs: one fetch for a whole language

## Why
Loading a language today is 3+ round trips (dict aff+dic, tier, buckets,
sometimes registry) - the rs PR #28 sketch showed a single length-prefixed
pack is simpler for SDK users and cuts playground cold loads.

## Work
1. models repo: pack builder (dict sources + tier + buckets concatenated,
   length-prefixed sections; kotoshu://packs/{lang} additive registry
   entries, versioned with their parts); v1.6.0 when validated.
2. kotoshu-rs: wasm loadPack(bytes) -> {dictionary, model} handle; worker
   package gains pack mode; keep per-artifact loading as fallback.
3. Site: playground opt-in pack path with one progress bar.

## Verification
Pack bytes == concatenation of parts (checksums per section); parity
specs per language; playground CDP cold-load comparison (requests and ms).

## Status
Pending
