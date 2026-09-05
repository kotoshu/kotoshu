# 92 — Tier mirror CORS: finish the browser-models distribution

## Context

The wasm model API shipped (kotoshu-rs PR #12: `loadModel` +
`rerank`), but the CORS spike found NO browser-usable source for tier
bytes: release assets send no ACAO; jsDelivr gh serves only 134-byte
LFS pointers. The ORIGINAL proposal (tier blobs in the git tree +
`browser_url`) would add ~1 GB to the repo — rejected on reflection.

The right fix is already half-built: **the media-host mirror sends
`Access-Control-Allow-Origin: *`** (proven by the spike) but today
mirrors only the 120 MB full tier (`mirror: null` for mini/fluency).

## Job (models repo)

1. Extend media-host mirroring to the mini and fluency tiers for all
   54 languages (the mirror upload path exists for full; tiers are
   3-15 MB, cheaper to mirror than full).
2. Populate `mirror` for tier entries in registry.json; schema
   unchanged.
3. Verify from a browser-like context: `curl -I -H "Origin:
   https://www.kotoshu.org" <mirror-url>` shows ACAO on tier files
   AND the registry itself (the registry must stay fetchable too —
   raw.githubusercontent already sends ACAO:*; document both paths).
4. Release v1.2.1 (patch = distribution fix per plan 05 policy),
   byte-identity + asset checks as usual.
5. Record in this file's Status the exact fetch recipe for the
   playground (registry URL + tier mirror URLs + the wasm API) so the
   site wiring is mechanical once @kotoshu/wasm 0.2.0 is published
   (that publish remains owner-gated).

## Status

**Pending.**
