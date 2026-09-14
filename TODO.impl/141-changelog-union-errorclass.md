# Plan 141: changelog truth, listing union, input-file error

## Status: executed

## Problem

1. **The CHANGELOG stopped at 0.7.0.** Versions 0.8.0 through 1.0.5 —
   two weeks and fourteen releases including 1.0.0 itself — were
   entirely absent while the file's header claims "all notable
   changes". The stale `Unreleased` section still held plan 81–109
   items that shipped long ago.
2. **`languages_setup` listed spelling only.** A model/typo-only setup
   (`want: %i[model]`) was invisible to `kotoshu setup --list` and the
   cache status report.
3. **`check_file` raised `DictionaryNotFoundError` for a missing INPUT
   file** (flagged in plan 140) — actively misleading: users diagnose
   dictionary setup for a typo'd path.

## Changes

- **CHANGELOG rebuilt**: every release 0.8.0 → 1.0.5 has a section,
  reconstructed from the per-tag git ranges (plus the wave records for
  0.8.0, whose tag is anomalously placed at v0.7.0's commit — the
  section follows the wave-5/wave-7 split: similarity clamp +
  plans 81–91 in 0.8.0, nb module + the #93 rescues in 0.9.0). The old
  `Unreleased` items moved into their shipping versions; `Unreleased`
  now holds the post-1.0.5 work (plans 140/141 + the verify retry).
- **`languages_setup` unions all caches**: spelling ids, frequency
  dirs filtered through `supports_resource?`, model ids filtered to
  models-layout types (`onnx`, `typo-matrix` — the model cache's
  metadata walk sees the shared root and yields foreign entries like
  `languages:en` for spelling metadata) minus the language-less `lid`.
- **`Kotoshu::InputFileNotFoundError`** (`< Kotoshu::Error`, autoloaded
  like its siblings) raised by `check_file`/`check_directory` for
  missing paths. The CLI already guards earlier (exit 2, usage error);
  this is the library-level truth.

## Evidence

- 91 examples across the touched suites, 0 failures; rubocop clean.
- Live: `setup --list` unchanged where correct, no `languages` leak;
  model-only seeding lists the language; lid/typo-pair seeds list
  nothing.
- CHANGELOG: 14 new version sections, descending, every tag ranged.

## Behavior note

`InputFileNotFoundError` replaces `DictionaryNotFoundError` for
missing inputs — callers rescuing the dictionary class for missing
INPUT files were relying on a misnamed error; documented under
Unreleased → next release.
