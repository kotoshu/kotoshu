# Plan 106 — Document language detection through the pure-Rust LID reader

## Why
The gem's LanguageIdentifier needs the Python fastText bindings (and breaks
under numpy 2), so /v1/detect ships a 7-language heuristic. kotoshu-rs now
carries a pure-Rust lid.176 reader (kotoshu/src/lid, parity 55/55 vs the
gem) behind the same `model` feature the native ext already builds.

## Work (gem repo)
1. Expose `Kotoshu.detect_language(text)` through the native backend:
   download/resolve lid.176.onnx + vocab via the models registry
   (kotoshu://models/lid/lid-176, v1.4.0), score with the ext, return
   { code, score }. Heuristic Language::Detector stays the fallback when
   the native ext is absent or the model is not set up.
2. FFI seam: extend the magnus shim (ext/kotoshu_native) with the call —
   mirror how suggest/check already cross; keep it behind the existing
   feature so pure-Ruby installs are unaffected.
3. Server follow-up (kotoshu-server repo, separate PR riding this):
   /v1/detect prefers Kotoshu.detect_language when available. Note it in
   the PR body; do not touch the server repo yourself.
4. Specs: native-vs-fixture parity (reuse the rs corpus JSON shape),
   fallback behavior, registry miss error.

## Verification
Suite green; a live detect over en/de/ru/ja/ar samples recorded in the PR
body; pure-Ruby suite still green (no new hard dependency).

## Status
Pending
