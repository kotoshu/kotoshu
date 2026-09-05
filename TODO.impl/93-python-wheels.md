# 93 — Python wheels for every platform + PyPI trusted publishing

## Context

`kotoshu-native` 0.1.0 on PyPI ships an sdist + one cp310 macOS
arm64 wheel — every other Python user compiles from source (needs
Rust). maturin + cibuildwheel in CI produces the matrix mechanically.

## Job (kotoshu-python repo)

1. CI workflow building wheels: linux x86_64 + aarch64 (manylinux),
   macOS x86_64 + arm64, windows; Python 3.10-3.13; maturin
   sdist+wheel; artifact upload; a pip-install-and-import smoke per
   platform.
2. PyPI trusted publishing workflow (pypa/gh-action-pypi-publish,
   id-token: write) gated on a tag — consistent with the ecosystem's
   keyless posture. The OWNER registers trusted publishers at
   pypi.org/manage/account/publishing for kotoshu + kotoshu-native
   (workflow filename, no environment); publishing itself waits for
   the owner's version call.
3. Docs: README wheel-matrix table + the owner registration steps.

## Status

**Pending.**
