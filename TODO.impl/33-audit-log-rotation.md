# 33 — Audit log rotation (T3, deferred past 0.3)

## Status
**Implemented** (2026-06-29). Shipped as `Kotoshu::Integrity::RotationPolicy`
plus rotation wiring in `Kotoshu::Integrity::AuditLog`. Configuration
exposed via `audit_max_bytes` / `audit_rotations` in `Configuration::SCHEMA`
and `BaseCache#default_audit_log` constructs the policy from configuration.

## Problem
`Kotoshu::Integrity::AuditLog` writes to `~/.local/share/kotoshu/audit.log`
unbounded. Long-running users accumulate megabytes of audit entries with
no rotation.

## Plan (as implemented)

### Rotation policy
- Pure value object `Kotoshu::Integrity::RotationPolicy`.
- `max_bytes` (default 10 MB, `KOTOSHU_AUDIT_MAX_BYTES`).
- `rotations` (default 5, `KOTOSHU_AUDIT_ROTATIONS`).
- `#rotate?(current_size)` returns true when size exceeds `max_bytes`.
- `#plan_for(path)` returns `{ deletes: [...], moves: [...] }` describing
  the rename dance: drop the oldest rotation slot, shift each remaining
  rotation up by one suffix, then promote the current log to `.1`.

### AuditLog integration
- `AuditLog.new(rotation_policy:)` accepts a policy (nil disables rotation).
- `#record` consults the policy on every write under an exclusive flock
  on a sibling lockfile (`audit.log.lock`). The lock target is the
  lockfile rather than the log itself because the log path moves during
  rotation; locking the log would carry the lock with it.
- `#entries` and `#each` walk the current log and every rotation
  (newest-first).
- `#clear!` removes the current log and every rotation.
- `BaseCache#default_audit_log` constructs the policy from
  `Configuration.instance` so ENV overrides and programmatic settings
  flow through naturally.

### Config
Added to `Configuration::SCHEMA`:
- `audit_max_bytes` (default 10_485_760) via `KOTOSHU_AUDIT_MAX_BYTES`.
- `audit_rotations` (default 5) via `KOTOSHU_AUDIT_ROTATIONS`.

## Acceptance

- [x] Audit log never exceeds `audit_max_bytes * (audit_rotations + 1)`.
- [x] Rotation preserves previous entries.
- [x] No lock contention — writes are synchronous and serialized via
      flock on a stable sibling lockfile.

## Why deferred (originally)
Audit log is append-only and unbounded today, but doesn't actively break
anything for 0.3 users. Rotation is a known best practice; shipping
without it for 0.3 is acceptable.

