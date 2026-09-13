# Plan 134 — Post-131 improvements: the audit's honest gaps

Status: executing (written from the 2026-09-13 deep audit of everything
the campaigns shipped, not from the backlog)

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
