# Plan 119 — Embed the frozen Kelly tiers in the gem

Status: pending
Depends on: plan 117 (the dataset-divergence forensics)

## Problem

Plan 117 made suggestion ranking deterministic for machines with
frequency data, but a cache-cold machine still falls back to
`lib/kotoshu/data/common_words/en.yml` — a *differently curated*
dataset (top_50 holds `a`; Kelly holds `a` in top_1000). The Rust
engine embeds the frozen Kelly tables (`kotoshu-rs
kotoshu/src/suggest/frequency_data.rs`, en.json sha256 97535823f41aa3f0…)
as its *only* source; the Ruby engine downloads them. Two engines, two
data paths, one contract — the fallback path is still
contract-divergent by construction.

## Design (single source of truth, model-driven)

- Generate `lib/kotoshu/data/frozen_kelly/en.rb` FROM the rs tables
  (script: `scripts/generate_frozen_tiers.rb`, documented provenance:
  the rs file path + the en.json sha). Content: three sorted word
  arrays, sizes 47/185/907, byte-identical membership to the rs
  `TOP_50`/`TOP_200`/`TOP_1000`.
- `Suggestions::FrozenTiers.tiers_for(language_code)` — returns the
  Set-shaped tiers for `en`, nil otherwise. Pure, no IO.
- `FrequencyProvider#load` fallback chain becomes:
  cache (any present data, plan 117) → **frozen embedded (en)** →
  local YAML → empty. For `en` the YAML is thereby unreachable; for
  every other language nothing changes (rs embeds en only — MECE with
  the Rust side).
- Cache-cold machines now produce contract-exact ranking for `en`
  with zero network, zero setup — determinism by construction instead
  of by CI seeding.

## Acceptance

- `XDG_CACHE_HOME=<empty>` conformance compare: 2630/0/0 (today the
  empty-cache run fails 16 — the CI seed papers over it).
- Parity spec: embedded tiers == the tiers `FrequencyCache` returns
  for a checksummed en download (structural: sizes + sampled words +
  `a` in top_1000 / `the` in top_50).
- Full suite green; no behavior change for cache-present machines.

## Non-goals

- No YAML deletion (other languages still use it; `en.yml` stays for
  now as a documented dead fallback — removal is a 1.x deprecation
  decision).
- No registry or format changes.
