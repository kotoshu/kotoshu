# Plan 134 — Post-131 improvements: the audit's honest gaps

Status: executed (2026-09-13). (1) GVL release rs PR #39 — the
without_gvl helper runs the typo compute through
rb_thread_call_without_gvl, PROVEN LIVE: a 5 ms ticker thread logged
4,118 ticks during the 24.8 s / 100k-word index build (a held GVL
starves it to ~0), suggest answers 2.2 ms after the eager build; gem
PR #195 makes Engine.for build eagerly. (2) native-suite CI leg (gem
PR #195): the conformance workflow compiles the extension and runs
the full suite — NativeBackend can no longer regress matrix-green.
(3) release verify (gem PR #195): the release asserts all six
RubyGems artifacts before reporting success. (4) runbook models PR
#37: docs/RELEASING.md carries the standard cut and the typo
promotion steps. (5) perf-weekly (gem PR #195): the weekly slow-suite
run whose first execution caught the suites rotted — repaired with
dated 2x-headroom bounds. Found and fixed en route (gem PR #196,
merged): setup_typo_remote rescued only Kotoshu::Error, leaking raw
Errno::ECONNREFUSED on Windows (caught by merge-preview CI on main).

Depends on: plan 131 (the typo layer), plan 133 (the platform gems)

## The items

### 1. The typo layer's first-suggest stall (production defect class)

The 100k-word index build (~15 s) happens lazily inside the first
`typo_suggest`, and the Ruby binding holds the GVL for the whole Rust
call — on the server, one arming request blocks every other request
for the build's duration. Fixes, both:

- The binding releases the GVL around the pure-Rust compute (index
  build and scan touch no Ruby objects; results re-enter GVL scope to
  build hashes), so a build never stops the world.
- The gem resolves EAGERLY: `Engine.for` builds the index at load —
  the cost moves to opt-in setup where it belongs, never mid-check.

### 2. The native path is invisible to the main rake matrix

The nine rake legs report the native specs PENDING ("native extension
not built"); only the separate compare job compiles the ext. A
`NativeBackend` regression could land matrix-green. One dedicated
matrix job compiles the extension and runs the suite un-pended.

### 3. The release workflow trusts its own pushes

Nothing asserts the release is COMPLETE — a silently failed platform
push ships a partial release green. A `verify` job after the native
legs queries the RubyGems API for version x platform coverage (ruby +
the five native platforms) and fails on anything missing.

### 4. The owner's cut-day procedure lives in session memory

The three-step typo release checklist is recorded in memory and PR
bodies. The models repo carries the committed runbook instead — the
owner cuts the release without needing this session.

### 5. The weekly SLOW_TESTS dashboard, owner-free form

The T4.2 remainder as a workflow: weekly run of the slow suites, the
delta summary posted on the run page (a job summary + artifact — no
external dashboard to own).

## Gates

- Every fix ships with its spec or CI proof; no behavior change to
  any frozen output (the GVL release is invisible; eager build moves
  WHEN the same index is built, not what it computes).
