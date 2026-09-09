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
Executed 2026-09-09 — models PR #26 + kotoshu-rs PR #32, both merged.
KPK1 format (length+tag framed sections, sha256 footers, golden-sha parity
across implementations); en/de/pt packs LFS-committed with live mirrors;
additive kotoshu://packs/{lang} entries; wasm loadPack + worker pack mode
with per-artifact fallback. Registry v1.6.0 cut awaiting owner; site
playground flip optional (worker package already serves pack mode).
