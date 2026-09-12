# Plan 133 — Rust-first distribution: precompiled native gems and complete wheels

Status: executed (2026-09-12) — PR #189 (7-iteration CI chain: the
MinGW Rust toolchain for the ABI match, bindgen pointed at the
RubyInstaller devkit's ucrt64 headers through BINDGEN_EXTRA_CLANG_ARGS
with the windows-gnu target, macos-13 -> macos-15-intel for the retired
x86_64 macOS runner, and the release race fix so the native legs build
from the v<version> tag). Released as kotoshu 1.0.2: six artifacts on
RubyGems (ruby + x86_64-linux, aarch64-linux, arm64-darwin, x86_64-darwin,
x64-mingw-ucrt), verified by a toolchain-free scratch-GEM_HOME install
that resolved kotoshu-1.0.2-arm64-darwin, engaged the native engine
under the auto default, and passed the frozen vectors. Docker: both
images (docker-kotoshu-ci PR #2, kotoshu-server PR #9) dropped their
build-tool layers / gained the native-backend build assertion, with the
guard proving the platform gem resolves inside the slim builder. Site:
engines section resolution paragraph + the 1.0.2 news entry (092fc03).
Design deviation: no x86_64-linux-musl platform gem — there is no
hosted musl Ruby runner and cross needs a musl Ruby; Alpine resolves
the pure-Ruby gem (source-build of the extension remains possible
there). Python: the 16-wheel + sdist kotoshu-native 0.1.1 matrix is
built and smoke-green (run 34681280341) but the PyPI publish is gated
on the owner registering the trusted publisher (pypi.org, project
kotoshu-native, repo kotoshu-rs, workflow release-pypi.yml, env blank);
rerun `gh run rerun 34681280341 --repo kotoshu/kotoshu-rs --failed`
afterward — the wheel artifacts persist, no rebuild needed.
Depends on: the 1.0 conformance contract (identical outputs make the
backend default flip correctness-free); plan 93 (the python wheel matrix)

## Problem

The Rust engine is the faster implementation (~10-15x on the sweep) and
the strategic default, but today reaching it requires a build toolchain:
the gem compiles its native extension at install time, and the python
native wheel matrix is incomplete on PyPI. Users who cannot run a
toolchain get pure Ruby whether they wanted it or not — and users who
wanted Rust pay a compile for it. The architecture makes both engines
byte-identical, so distribution — not capability — is the only gap.

## Design

### Ruby: precompiled platform gems (the rb_sys flow)

1. New gem workflow `release-native.yml`: build matrix over
   {x86_64-linux, aarch64-linux, x86_64-linux-musl, arm64-darwin,
   x86_64-darwin, x64-mingw-ucrt} x {ruby 3.1..4.0} using
   rb-sys-dock images for the Linux targets and native runners for
   macOS/Windows; each job builds and pushes
   `kotoshu-X.Y.Z-<platform>.gem` through trusted publishing. The
   pure-Ruby platform gem continues to publish exactly as today, so
   every unmatched platform resolves to it.
2. Backend default `ruby` -> `auto`: use the native engine when the
   extension loads, fall back silently to pure Ruby when it does not.
   Auto never downloads and never fails a check; specs pin both
   branches; the conformance job already runs both engines.
3. The docker CI image drops its build-tool layer (it installs the
   platform gem instead) — smaller image, faster builds, and its
   version guard gains a native-backend assertion.

### Python: complete the kotoshu-native wheel matrix

1. Audit PyPI's published wheels for kotoshu-native against the
   plan-93 matrix: manylinux x86_64/aarch64, macOS x86_64/arm64,
   windows x86_64 (+ arm64 if tractable), sdist.
2. Fill the gaps in release-pypi.yml (maturin + the standard target
   matrix), publish a patch release, and verify pip resolves a wheel
   (no source build) on each platform.
3. Add the trove classifiers for every published target.

### Site

Install page's engines-and-bindings section gains the resolution
sentence: the native engine installs automatically wherever a prebuilt
artifact exists for your platform, and pure Ruby is always the
fallback; python's entry notes the wheel coverage.

## Gates

- A clean-machine `gem install kotoshu` on each published platform
  loads the native backend with no toolchain present (CI-verifiable
  on the matrix runners).
- The 2,630-vector conformance compare passes under `auto` on both a
  native and a pure-Ruby install.
- pip on each target platform resolves a wheel, not the sdist.
- The pure-Ruby path is unchanged: same gem, same outputs, same specs.

## Non-goals

- No behavior change of any kind — outputs are frozen; only which
  engine computes them changes.
- No deprecation of anything: pure Ruby is a feature, not a legacy.
