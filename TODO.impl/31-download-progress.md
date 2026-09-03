# 31 — Download progress indication (T2, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `lib/kotoshu/cli/progress_reporter.rb` — `Kotoshu::Cli::ProgressReporter`
  (TTY progress bar, periodic-line fallback, plus a silent Null variant).
- Wired through Configuration, not per-cache globals: the CLI installs a
  reporter on `Kotoshu.configuration.download_reporter` during setup
  (`lib/kotoshu/cli.rb:331-337`).
- Shared download helper: `BaseCache#download_file(url, dest_path,
  reporter:)` streams in chunks and honors Content-Length with a
  fallback (`lib/kotoshu/cache/base_cache.rb:308+`); `ModelCache` also
  reports decompression progress every 10 MB (`model_cache.rb:775`).
- Spec: `spec/kotoshu/cli/progress_reporter_spec.rb` — run 2026-09-03
  together with check_format_spec: 8 examples, 0 failures.

Not visually re-verified on a 114 MB download today (dev cache has no
models); chunked-stream behavior is spec-covered.

## Problem
Downloads (114 MB ONNX models in particular) sit silently. Users have
no idea whether the gem is hung or making progress.

## Plan

### New module: `Kotoshu::Cli::ProgressReporter`

Wraps download operations. Detects TTY:
- **TTY:** renders a progress bar to stderr (`[====>     ] 45% 51MB/114MB`).
- **Non-TTY:** prints periodic line messages (`downloaded 51MB of 114MB`).

### Wire into caches
All three caches (`LanguageCache`, `FrequencyCache`, `ModelCache`) call
a new shared helper `Kotoshu::Cache.download_with_progress(url, dest)`
instead of inline `URI.open(...).read`.

The helper:
1. Opens connection.
2. Reads `Content-Length`.
3. Streams body in chunks, updating progress per chunk.
4. Falls back to indeterminate progress bar when no Content-Length.

### No `respond_to?`
Detecting "is this a TTY" uses `$stderr.tty?` (a method call, not type
check). No `respond_to?` patterns.

## Acceptance

- [ ] `kotoshu setup en` shows progress bar in TTY.
- [ ] `kotoshu setup en` in CI shows periodic line output.
- [ ] 114 MB ONNX download shows incremental progress.
- [ ] No regression in offline mode (`KOTOSHU_OFFLINE=1`).

## Dependencies
- None (independent).
