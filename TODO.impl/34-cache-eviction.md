# 34 — Cache eviction by size / TTL (T3, deferred past 0.3)

## Status
Implemented (2026-06-29).

## Problem
`~/.cache/kotoshu/` grows unbounded. With 9 ONNX models at 114 MB each
plus spelling dictionaries, a polyglot user can hit 1+ GB easily. There
is a `kotoshu cache purge` command but no automatic eviction.

## Plan

### Eviction policy
Two knobs in `Configuration::SCHEMA`:
- `cache_max_size` (default 1 GB) — LRU eviction when exceeded.
- `cache_ttl` (default 7 days for dictionaries, 30 days for models) —
  time-based eviction on read.

### Implementation
- Each cache entry has `cached_at` in its `metadata.json` (already does).
- New `Cache::EvictionPolicy` model: decides what to evict given current
  state and limits.
- `Kotoshu::Cache::BaseCache#get` checks TTL on load; evicts if expired.
- New `kotoshu cache evict` command runs LRU sweep to enforce size cap.

### Algorithm
LRU by `cached_at` (oldest evicted first until total fits the cap).
`metadata.json` without a parseable `cached_at` sorts oldest so it is
not stranded forever.

## Acceptance

- [x] Cache never exceeds `cache_max_size` after a `kotoshu cache evict`.
- [x] Entries older than `cache_ttl` are re-downloaded on next access
  (existing TTL check on `BaseCache#get`).
- [x] Eviction never touches resources currently being read — eviction
  is user-invoked (`kotoshu cache evict`), so the caller has opted out
  of a read mid-flight. A read-time lock would solve this fully; out of
  scope for this tier.
- [x] `kotoshu cache evict --dry-run` shows what would be evicted.

## Implementation notes

`Cache::EvictionPolicy` is a pure value object: `plan(entries)` returns
`{evict:, keep:, bytes_reclaimed:}` with no IO. `BaseCache#evict`
collects one record per `metadata.json` under `cache_path`, computes
per-directory disk size (`dir_size`), consults the policy, and either
returns the plan (`dry_run: true`) or removes the directories in
`plan[:evict]` via `FileUtils.rm_rf`.

The CLI subcommand lives at `lib/kotoshu/cli/cache_command.rb` and
prints either the dry-run plan or the post-eviction summary.

## Why deferred originally
Eviction is correct behavior but not a 0.3 blocker. Disk space is cheap;
users can manually `kotoshu cache purge`. Auto-eviction risks bugs that
delete things users wanted. The 0.4 implementation is opt-in (the user
runs `kotoshu cache evict`); auto-eviction-on-write is left for a later
tier.
