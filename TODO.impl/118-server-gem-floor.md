# Plan 118 — kotoshu-server 1.0 must ride kotoshu 1.0

Status: pending (P0 — broken release constraint)
Priority: P0 (a shipped 1.0.0 release cannot see the 1.0 gem)

## Problem

`kotoshu-server.gemspec` declares `spec.add_runtime_dependency "kotoshu",
"~> 0.6"`. Ruby's pessimistic operator makes that `>= 0.6, < 1.0` — so
the server 1.0.0 released in the 1.0 train resolves **kotoshu 0.11.1**,
not 1.0.0. Every fresh `gem install kotoshu-server` today deploys the
pre-freeze engine under a 1.0 label. The floor was never revisited as
the gem moved 0.6 → 1.0.

## Fix

- `spec.add_runtime_dependency "kotoshu", "~> 1.0"` — the server's
  public surface consumes stable gem API only (two-stage setup, check
  facade, semantic cascade), all frozen at 1.0.
- Release kotoshu-server 1.0.1 carrying the floor bump.
- Guard: a spec that parses the gemspec and asserts the runtime floor
  does not exclude the current kotoshu major (the class of bug is
  silent by construction).

## Acceptance

- `gem dependency kotoshu-server -v 1.0.1` shows kotoshu ~> 1.0.
- A fresh resolve (`gem install kotoshu-server --version 1.0.1` in a
  scratch GEM_HOME) picks kotoshu 1.0.x.
