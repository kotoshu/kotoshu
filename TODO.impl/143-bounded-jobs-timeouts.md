# Plan 143: bounded CI jobs, complete HTTP timeouts

## Status: executed

## Problem

1. **Unbounded jobs.** GitHub's default job ceiling is 360 minutes. A
   hung job (the plan-142 round watched a network-tests run sit
   35+ minutes on one spec before cancel) burns hours of runner time
   and stalls PRs whose only red is a stall. Several hang-prone jobs
   had no `timeout-minutes`.
2. **Partial HTTP timeouts.** Both Net::HTTP sites set open/read
   timeouts but not `write_timeout` — incomplete coverage of the
   transport (reads dominate, but the gap is free to close).

## Changes

- `timeout-minutes`: conformance native-suite 30, perf-weekly 60,
  release native legs 45, release verify 15. (network-tests already
  carried 30 — the observed hang was cancelled just past it.)
- `http.write_timeout = 30` on `Integrity::NetHTTP` and
  `BaseCache#download_file`.

## Evidence

- All four workflows parse; 239 examples across integrity + cache
  suites green after the timeout additions.

## Note

Downloads already enforce open(30s)/read(300s per chunk); a slow-drip
server can still stretch a transfer, but the job ceilings now bound
the worst case end to end.
