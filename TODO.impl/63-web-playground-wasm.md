# 63 — Web playground (WASM)

Promotes T6.2 in `TODO.impl/56-t4-t5-t6-quality-architecture-ecosystem.md`
into a promotable plan.

## Goal

A browser-only Kotoshu playground at `play.kotoshu.dev` (or under
`kotoshu.github.io/playground/`) that:

- Loads instantly, no signup, no backend.
- Spell-checks user-pasted text in real time.
- Demonstrates the library's capabilities (suggestions, language
  detection, document-format awareness) as a marketing surface for the
  gem.

Built on [ruby.wasm](https://github.com/ruby/ruby.wasm), so the actual
Kotoshu Ruby code runs in the browser — not a JS port, not a server
round-trip.

## Why

A playground is the canonical "try before you install" for developer
tools. Without one:

- Curious users have to `gem install`, set up a language, and write a
  Ruby script just to see what Kotoshu does. Most bounce.
- The semantic path (the gem's standout feature) is invisible until
  you've installed onnxruntime and a 4 GB model — a non-starter for
  casual evaluation.

A WASM playground flips that: paste, see, decide. It also doubles as:

- **A bug-report reproducer** — link a playground URL with the failing
  text in issues.
- **A feature showcase** for the marketing site (plan in
  `kotoshu.github.io/TODO.impl/`).
- **A regression test surface** — snapshot outputs across releases.

## Constraints (these shape every task)

- **No native extensions in the browser.** WASM Ruby cannot load C
  extensions. This means:
  - No `onnxruntime` — the semantic path is not available in-browser.
  - No `suika` — Japanese tokenization (the dartsclone native ext) is
    unavailable. Japanese either ships with a pre-tokenized dictionary
    or is omitted from the playground.
  - No `rubyzip` — bundle dictionaries unpacked.
- **Size budget.** ruby.wasm is ~3 MB. A full Hunspell dictionary is
  ~5 MB compressed. A full FastText `.vec` is 2 GB. The playground
  cannot ship the full corpus.
- **Cold start.** WASM Ruby instantiation takes ~1–2 s on a fast
  machine, more on mobile. The UI must hide that behind a loading
  state.

## Tasks

### Phase 1 — Minimum viable playground

1. **Pick the dictionary subset.** Ship a top-50K-words-per-language
   subset of the Hunspell `.dic` plus the full `.aff` (affixes are
   small). 50K covers >99% of typical prose. Subset lives in the
   `kotoshu.github.io` repo under `playground/dictionaries/<code>/`.
2. **Language support.** Start with the six full-feature languages
   (de, en, es, fr, pt, ru). Document that Japanese is omitted (no
   suika in WASM); other languages follow as language modules land
   (plan 04).
3. **ruby.wasm packaging.** Build pipeline (Rakefile in the
   `kotoshu.github.io` repo) that:
   - Compiles a `kotoshu.wasm` with the gem baked in.
   - Strips the gem's `onnxruntime`, `suika`, `rubyzip` require paths
     via conditional loading (the library already soft-requires them —
     verify WASM mode is treated like the "neither soft-dep installed"
     case).
   - Bundles the 50K-word dictionaries as gzipped JSON.
4. **UI shell.** Single page:
   - A textarea (or Monaco editor for syntax-highlighting) on the left.
   - A diagnostics panel on the right, mirroring what the LSP server
     emits (plan 60).
   - A language selector (defaults to auto-detect).
   - A "Format" toggle (plain / markdown / asciidoc) to demo document
     parsing.
5. **In-browser caching.** IndexedDB stores the WASM blob, the
   dictionaries, and the user's personal dictionary. Subsequent visits
   load from cache.

### Phase 2 — Showcase features

6. **Suggestion panel.** Clicking a flagged word shows ranked
   suggestions with frequency-rank badges (from the Kelly lists, if
   the playground ships them).
7. **Language detection demo.** A visible "Detected: fr (95%
   confidence)" badge using the pure-Ruby heuristic path
   (`Language::Identifier` falls back to n-gram detection when the
   FastText LID model is unavailable — verify this is what happens in
   WASM, or ship the LID model if feasible).
8. **Permalinks.** The textarea content is encoded in the URL hash
   (compressed with `lz-string`) so users can share a reproduction
   case.
9. **"Get this in your editor" CTA.** A footer banner linking to the
   install instructions (plan 61) for users who want it locally.

### Phase 3 — Performance and reliability

10. **Lazy dictionary load.** Don't ship all six dictionaries upfront;
    fetch the relevant one on first language detection. Cache for
    subsequent visits.
11. **Web Worker.** Run Kotoshu in a Web Worker so spell-checking
    doesn't block the UI thread. Debounce by 500 ms.
12. **Offline support.** Service Worker caches the WASM + dictionaries
    so the playground works without network after first load.
13. **Memory ceiling.** Browsers tab-dismiss pages that exceed memory
    budgets. Cap resident memory at ~100 MB; refuse to load a second
    dictionary until the first is released.

### Phase 4 — Operations

14. **Hosting.** GitHub Pages on `kotoshu.github.io`. Subpath
    `/playground/` or a custom subdomain via CNAME.
15. **CI build.** On release of the library gem, a workflow rebuilds
    the WASM and deploys. Version the playground to match the gem so
    bug reports reference a known state.
16. **Telemetry.** Privacy-respecting: count unique visits, top
    languages used, top error patterns. No user content logged. Use
    Plausible or self-hosted; never Google Analytics.

## Acceptance criteria

- `https://kotoshu.github.io/playground/` loads in under 5 s on a
  cold cache (3G simulation), under 1 s on a warm cache.
- Pasting English prose flags misspellings within 500 ms of typing
  pause.
- Selecting a suggestion replaces the word in the editor.
- Sharing a permalink reproduces the exact state.
- The page works offline after first visit.
- Memory stays under 100 MB with one language loaded; under 200 MB
  with three.

## Dependencies

- **Blocked by:**
  - `02-cli-unification` — the playground wraps the library API; a
    clean surface is required
  - `04-language-modules` — for the languages available in the
    playground (only languages whose tokenizer + normalizer is pure
    Ruby can ship in WASM)
- **Blocks:** nothing — this is a marketing/UX surface, not a
  prerequisite for other features.
- **Cross-repo:** ships in `kotoshu/kotoshu.github.io`; consumes the
  library gem's WASM build (which the library repo must produce — see
  task 3).
- **Promotes from:** T6.2 in `56-t4-t5-t6-quality-architecture-ecosystem.md`

## Out of scope

- The semantic path in-browser. No `onnxruntime` in WASM; revisit if
  ONNX-runtime-on-WASM matures (it's nascent in 2026).
- A full FastText model (2 GB per language is not browser-feasible).
- User accounts or saved documents. The playground is for trying, not
  for storing.
- A full dictionary (every word, every language). The 50K subset is a
  deliberate tradeoff for size; users who need full coverage install
  the gem.

## Risks

- **ruby.wasm maturity.** ruby.wasm is actively developed; some stdlib
  pieces behave differently (notably `IO`, `File`, `Thread`). Audit
  the Kotoshu codepath for stdlib calls that don't translate and add
  WASM-specific stubs.
- **Bundle size creep.** Easy to accidentally ship the full gem
  (with onnxruntime glue code) — the build pipeline must tree-shake
  aggressively. Set a CI gate on the WASM blob size.
- **Browser memory limits.** Mobile Safari is aggressive. Test on a
  real iPhone before claiming "works on mobile."
- **Dictionary licensing.** Each Hunspell dictionary has its own
  license. Verify the subset bundle is redist-compatible. The
  `dictionaries/` repo already tracks per-language licenses — reuse
  that metadata.

## Status

_Pending._ Phase 1 is a coherent MVP — could ship before v1.0 of the
library as part of marketing buildup. The single biggest risk is
ruby.wasm compatibility; spike task (verify Kotoshu loads in ruby.wasm
at all) before committing to a deadline.
