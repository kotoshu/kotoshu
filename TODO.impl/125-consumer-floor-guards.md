# Plan 125 — Dependency-floor guards in every consumer repo

Status: executed (docker PR #1; site push 70df393; 2026-09-12)

The guard found a REAL break on its first run: the docker CI image
could not install kotoshu at all since the native extension shipped
(ruby:slim lacks make; the 'no native ext' comment was stale). Fix:
build-essential + clang/libclang + rustup in the builder stage.
Dispositions: kotoshu-go has no artifact pin to guard (pure /v1 HTTP
client); kotoshu-python's native extra rides the deliberately-0.x
kotoshu-native line - a floor lands when that line crosses 1.0
(tracked in plan 124).
Depends on: plan 118 (the bug class: silent floor drift)

## Problem

Plan 118 found kotoshu-server shipping 1.0.0 with a runtime floor
(`~> 0.6`) that excluded the gem it was releasing alongside — and its
own CI had been bundling kotoshu 0.6.0 the whole time. The same
silent-drift class lives wherever a consumer pins a kotoshu artifact:
docker-kotoshu-ci (base image gem), kotoshu-go (embedded wasm/native
pins or docs), kotoshu-python (wheel cargo/git pin of kotoshu-rs).
Nothing reads those pins after they are written.

## Fix

Each repo gains the same guard shape the server got: a spec/test that
loads the pin (gemspec/Dockerfile/dependency manifest) and asserts it
admits the artifact version the repo actually builds/tests against.
A constraint nobody reads is guarded by a test that reads it.

- docker-kotoshu-ci: a CI step that installs the pinned gem and
  asserts `kotoshu --version` >= the floor the Dockerfile names.
- kotoshu-python / kotoshu-go: assert the pinned kotoshu-rs rev/tag
  resolves to the crate the wheels/binaries were built from (build
  metadata comparison), or at minimum that the pin admits the
  workspace version.

## Acceptance

- Each repo's CI fails if its pin excludes the version it builds.
- 124's inventory item "floors to check on next cuts" shrinks to
  "guards exist".
