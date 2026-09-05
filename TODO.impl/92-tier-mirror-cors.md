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

**DONE (2026-09-05, models PR #15 + tag v1.2.1).**

- All 54 languages x 2 tiers mirrored: every fasttext.{lang}.{mini,fluency}.onnx
  and its .vocab.json entered LFS as media-host objects; urls.mirror
  populated for all 162 resources (data rev 3 -> 4, schema unchanged).
  Binaries are the v1.2.0 release bytes - all 216 files sha256-verified
  against registry/tiers.json ground truth before staging, reused from the
  expand/batch2 worktrees, nothing rebuilt locally. The v1.2.1 release
  workflow rebuilt everything in CI and regenerated a registry whose 162
  sha256 values are identical to the committed one (only generated_at
  differs) - independent proof the mirror bytes equal the release bytes.
- Verification: 108/108 tier mirror URLs return HTTP 200/206 with
  access-control-allow-origin: * and content-length exactly equal to
  registry size_bytes (GET; note HEAD does NOT show ACAO on these hosts).
  16/16 vocab mirrors sha256-verified + ACAO. Release v1.2.1: 326 assets
  (162 onnx + 162 vocab + registry.json + manifest-v1.2.1.json).
- Docs: README browser/wasm section + plan-92 addendum in
  docs/storage-decision.md (rejected alternative: plain git blobs ~1 GB
  per clone).

### Browser fetch recipe (playground wiring, mechanical)

```js
// 1. Registry - plain git file, raw host sends ACAO:* (real JSON, never
//    an LFS pointer):
const REGISTRY_URL = (tag) =>
  `https://raw.githubusercontent.com/kotoshu/models-fasttext-onnx/${tag}/registry.json`;

// 2. Model bytes - release assets send NO ACAO; use the registry mirror
//    (media host = LFS content host, sends ACAO:*):
//    https://media.githubusercontent.com/media/kotoshu/models-fasttext-onnx/main/models/{lang}/fasttext.{lang}.{tier}.onnx
//    Vocab = same URL with .onnx -> .vocab.json (also LFS, also ACAO:*).

// 3. Engine - @kotoshu/wasm 0.2.0 (owner-gated publish), wasm-pack
//    bundler target; jsDelivr npm raw + manual init works (esm.sh/esm.run
//    do not for the bundler target - see plan 78 CDN pin):
import init, { loadModel, rerank } from "@kotoshu/wasm";

await init(/* fetch the .wasm yourself from the pinned CDN */);
const registry = await (await fetch(REGISTRY_URL("v1.2.1"))).json();
const entry = registry.resources[`kotoshu://models/${lang}/mini`]; // or fluency
const modelBytes = new Uint8Array(await (await fetch(entry.urls.mirror)).arrayBuffer());
const vocabBytes = new Uint8Array(await (await fetch(
  entry.urls.mirror.replace(/\.onnx$/, ".vocab.json"))).arrayBuffer());

const model = loadModel(modelBytes, vocabBytes);        // -> KotoshuModel
const score  = rerank(model, word, context);            // -> f32 in [-1, 1]
model.free();                                           // optional, before GC
```

Sizes per language: mini ~3 MB + vocab ~0.25 MB; fluency ~15 MB +
vocab ~1.3 MB. sha256/size_bytes in each entry verify the mirror
bytes. Remaining owner gate: publish @kotoshu/wasm 0.2.0, then the
/playground can flip the matrix on.
