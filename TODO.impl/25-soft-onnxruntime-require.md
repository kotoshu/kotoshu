# 25 — Soft ONNX runtime require (T1, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `kotoshu.gemspec` runtime deps are only `thor`, `rubyzip`,
  `lutaml-model` — no `onnxruntime` (nor `suika`; both documented as
  soft deps in comments).
- `lib/kotoshu/models/onnx_model.rb:25-34` — load-time
  `begin require "onnxruntime" ... rescue LoadError` sets
  `ONNX_LOADED = false`; `KOTOSHU_NO_ONNX=1` forces it off (opt-out,
  replacing the old opt-in).
- Actionable error: `OnnxModel::OnnxUnavailable` (ibid., lines 38-46)
  — "Install with: gem install onnxruntime".
- `KOTOSHU_REQUIRE_ONNX` is gone from `lib/` and the docs; the only
  remaining mentions are historical (CHANGELOG 0.1.0 entry) and in the
  plan files themselves.
- Live: `bundle exec exe/kotoshu status` reports
  `onnxruntime    loaded` on this machine.

## Problem
`onnxruntime` is a runtime dependency in `kotoshu.gemspec`:
```ruby
spec.add_dependency "onnxruntime", "~> 0.10"
```

But `Models::OnnxModel` only does `require "onnxruntime"` when
`ENV['KOTOSHU_REQUIRE_ONNX']` is set. Worst of both worlds:

1. `bundle install` can fail on platforms where `onnxruntime` doesn't
   build — the whole gem becomes unusable even for non-semantic use.
2. Even when installed, semantic analysis silently stays off until the
   user sets an env var they have no way to discover.

## Plan

### Step 1 — Move onnxruntime to soft dependency
Remove from `spec.add_dependency`. Document in README that semantic
features require `gem install onnxruntime` (or `bundle add onnxruntime`).

### Step 2 — Replace env-var gate with load-time rescue
In `lib/kotoshu/models/onnx_model.rb`:
```ruby
begin
  require "onnxruntime"
  ONNX_LOADED = true
rescue LoadError => e
  ONNX_LOADED = false
  warn "kotoshu: onnxruntime not available (#{e.message}); semantic analysis disabled"
end
```

### Step 3 — Fail with actionable error when semantic is requested but unavailable
`OnnxModel.from_file` raises `SemanticError` (already exists) with:
```
onnxruntime gem not installed. Install with: gem install onnxruntime
```

### Step 4 — Drop `KOTOSHU_REQUIRE_ONNX` env var
If users want to disable ONNX explicitly (e.g. to avoid the load warning),
support `KOTOSHU_NO_ONNX=1` as opt-OUT (inverted from current opt-IN).

## Acceptance

- [ ] `gem install kotoshu` succeeds without `onnxruntime` installed.
- [ ] `Kotoshu.correct?("hello")` works without `onnxruntime` (traditional path).
- [ ] Calling semantic methods without onnxruntime raises a clear `SemanticError`.
- [ ] After `gem install onnxruntime`, semantic methods work without any env var.
- [ ] `KOTOSHU_NO_ONNX=1` disables semantic even when onnxruntime is installed.
- [ ] No mention of `KOTOSHU_REQUIRE_ONNX` in code or docs.

## Dependencies
- None (independent).
