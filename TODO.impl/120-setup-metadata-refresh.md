# Plan 120 — setup refreshes cached_at when a download is skipped

Status: pending
Depends on: plan 117 (design item 4, deferred there)

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
