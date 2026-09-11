# Plan 120 — setup refreshes cached_at when a download is skipped

Status: resolved as obsolete (2026-09-11, code inspection during execution)

`setup_frequency_remote` (resource_manager.rb) has no checksum-skip
path: `return :cached if cache.available? && !force` — expiry makes
`available?` false — `else cache.get` → `download` → `download_resource`
ALWAYS writes fresh metadata (cached_at = now). The observed
"downloaded but stale timestamp" was plan 117's writer/reader path
split in full; no second mechanism exists. Verified by walkthrough of
get/setup_frequency_remote/download_resource; no code change needed.

## Problem

`Kotoshu.setup(:en, want: [:frequency])` can skip the download when
the checksum of the fetched bytes matches the cached file, but the
skip path historically left `cached_at` untouched (observed 2026-09-10:
setup reported `frequency: :downloaded` while the reader-side metadata
still said 2026-09-02). An unrefreshed timestamp guarantees the next
TTL check fails and the resource is re-fetched for nothing — and any
reader still consulting TTL sees stale.

## Fix

- On a checksum-matching skip: rewrite the metadata with a fresh
  `cached_at` (same checksum, same url) and report `:cached`, not
  `:downloaded`. The report must describe what actually happened.
- Spec: backdate metadata, run setup with a stubbed fetcher (no
  network), assert `cached_at` moved and the result says `:cached`.

## Acceptance

- Second consecutive `setup` run performs no re-download (checksum
  match) yet leaves a TTL-valid metadata file.
- Honest SetupResult reporting.
