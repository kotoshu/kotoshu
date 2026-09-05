# 79 — News + releases section on the site

## Context

The site has docs, languages, audiences, install — but no news.
Releases across seven registries shipped in 2026-09 and a visitor
cannot tell the project is alive. The owner asked for this
explicitly ("think also about documentation and our website
(e.g. docs, news)").

## Design

- `/news` — index, reverse-chronological, one entry per release or
  event, each rendered as a dictionary entry (date as the headword's
  etymology line; the entry body is the note).
- Entry pages `/news/<slug>` for anything longer than a paragraph.
- **RSS + Atom** at `/news/rss.xml` + `/news/atom.xml` (static).
- Design follows the site system (eyebrows, `辞書` vertical accent,
  numbered senses for changelog bullets). No blog-engine machinery —
  entries are typed content collections.

## Seed content (real history, verified 2026-09-05)

1. **2026-09-05 — Trusted publishing everywhere** — npm, RubyGems,
   crates.io now publish keyless via OIDC (RFC 3691 on crates.io,
   provenance on npm).
2. **2026-09-05 — First releases on all channels** — PyPI
   `kotoshu` + `kotoshu-native` 0.1.0; npm `@kotoshu/wasm` +
   `@kotoshu/client` 0.1.0; crates.io `kotoshu` 0.1.0.
3. **2026-09-05 — Ruby gem 0.7.0** — the universal-kotoshu cut:
   model tiers + registry, native extension (dual-backend parity,
   2630 conformance vectors, 0 divergences), legacy-cache bridge,
   tier default = fluency.
4. **2026-09-04 — Engine correctness wave** — compound/suggest
   parity with hunspell semantics (T2), 1315+1315 conformance green
   in Rust and Ruby.
5. **2026-09-03 — Models v1.0.x registry + tiers** — 9 languages ×
   3 tiers, keyboard-aware eval, media-host distribution.
6. **Earlier** — kotoshu-lsp 0.1.0, kotoshu-server 0.1.0,
   kotoshu-go v0.1.0, action-kotoshu v1, site launch.

Pull dates from the registries/gem CHANGELOG while writing — verify,
don't guess.

## Phases

1. Content collection schema + seed entries above.
2. `/news` index + slugs + feeds; nav + footer links; sitemap.
3. Cross-link: gem docs page → news; news → install.

## Owner gates

None.

## Status

**Pending.**
