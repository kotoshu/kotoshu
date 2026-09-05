# 78 — Zero-install wasm playground on the site

## Context

The site playground (`/playground`) currently requires a locally
running `kotoshu-server` — a real barrier for the curious visitor.
Since `@kotoshu/wasm` 0.1.0 is live on npm (291 KiB gz engine), a
zero-install in-browser demo is now possible: load the engine from a
CDN, fetch `.aff`/`.dic` + a mini-tier model, check text live.

This is the single highest-leverage marketing surface: every visitor
can feel the product in five seconds with no install.

## Design

- **Route**: keep `/playground` as the home of the in-browser demo;
  the server-based playground moves to `/playground/server` (linked
  as "run it against your own instance").
- **Engine**: `import { init } from "@kotoshu/wasm"` via a pinned
  CDN URL (esm.run / esm.sh, version-pinned to 0.1.x). Never
  `@latest`.
- **Dictionaries**: `kotoshu/dictionaries` repo files via jsDelivr
  `/gh/kotoshu/dictionaries@<tag>/<lang>.aff|.dic` — verify the
  tag layout first (dictionaries repo manifest). Files are < 20 MiB
  so jsDelivr gh CDN is legal.
- **Model**: mini tier from the models registry. Registry URLs point
  at release assets — verify browser CORS on
  `objects.githubusercontent.com` before committing to that source;
  fallback = jsDelivr gh for tag-tree files, else document the
  limitation and ship dictionary-only mode with a note that
  reranking needs the full app.
- **UX**: language select (defaults to browser language if one of
  the supported set), textarea with misspelling underlines,
  suggestion popover on click, tier badge (mini), first-load size
  readout. Reduced-motion respected; no layout shift.
- **Aesthetic**: follows the site's dictionary-catalog design
  system (site plans 05/09) — the playground is a "specimen" page,
  not a generic SaaS demo.

## Phases

1. **Fetch spike** (an hour): prove CORS + CDN loads for engine,
   one dictionary, mini model. Decide model source. If models CORS
   fails → dictionary-only v1, models behind the server playground.
2. **Component**: `PlaygroundLab.astro` + island
   (`client:load`), module-scope caching of loaded languages,
   Web Worker for the engine to keep typing at 60fps (the engine
   API is sync; worker keeps the main thread free).
3. **Wire routes**, update copy on `/` hero to link the demo
   ("try it now — nothing installs").
4. **Verify in a browser** before merge: golden path (load en,
   type a typo, get suggestions), CJK (ja), offline (graceful
   error), reduced-motion, mobile width.

## Owner gates

None. CDN pinning note: record the chosen CDN + version in this
file's Status when shipped.

## Status

**Implemented (2026-09-05, site PRs #1-#3, live at kotoshu.org/playground).**
Zero-install wasm demo: @kotoshu/wasm 0.1.0 in a worker, underlines +
click-to-mend popover, six languages; server playground moved to
/playground/server. CDN pin: jsDelivr npm raw files @0.1.0 with manual
instantiate (esm.sh and esm.run both broken for the bundler-target
package); dictionaries via jsDelivr gh @commit 1829a3e. Models verdict:
GitHub release assets send no CORS headers, so the demo is honestly
dictionary-only; the model story lives on the server playground page.
