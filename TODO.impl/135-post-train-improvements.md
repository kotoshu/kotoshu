# Plan 135 — Post-train improvements: the two gotchas the release train exposed

Status: executed (2026-09-14). (1) `rake ext:update` — cargo update
with the CLI git fetch, prints the resolved rs revision (verified
live: c810ced3b4), recompiles; spec freezes the wiring. (2)
miss-driven registry refresh — `registry_entry_for` retries once with
a forced registry fetch when the wanted entry is absent from the
cached copy; offline refresh failure keeps the original miss
(broadened rescue after the Windows Errno lesson). Proven with a real
local HTTP server: stale v1.4.0 cache + served v1.7.0 registry
downloads the fresh pair end to end. Suite 4064/0, rubocop clean.

## 1. `rake ext:update` — the rs-main pin's manual dance

The gem ext tracks kotoshu-rs main via a git dependency pinned in
`ext/kotoshu_native/Cargo.lock`. After every rs merge, the developer
must remember `cargo update -p kotoshu && rake compile` — forgetting
it loads a stale extension whose missing methods the typo layer's
silent-degrade rescue swallows (bit twice now). One task does the
dance: update the pin, print the resolved revision, recompile.

## 2. Miss-driven registry refresh — the stale-cache silent degrade

A cached registry within its TTL shadows the live one: during the
train, a v1.4.0 cache made `setup --typo` report `:unavailable`
against a v1.7.0 registry because the wanted entry was absent from
the STALE copy. The fix is miss-driven invalidation: when a wanted
resource is absent from the cached registry, refresh the registry
once and look again before falling back (legacy CDN for tiers, the
honest error for the typo pair). Offline refresh failure keeps the
original miss — existing fallbacks untouched.

## Gates

- The stale-cache spec: a seeded old registry + a served fresh one
  resolves the entry (fixture-driven, no network); the offline
  variant keeps today's behavior exactly.
- Suite green; no behavior change for cache hits.
