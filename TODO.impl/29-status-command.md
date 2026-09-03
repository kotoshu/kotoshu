# 29 — `kotoshu status` command (T2, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `bundle exec exe/kotoshu status` run 2026-09-03 — output matches the
  planned layout: version, Setup table (per-language × resource with
  size + cached date), Cache path/size/language count, Semantic
  (`onnxruntime loaded`, active models), Other (audit log path+size,
  default lang, offline mode). Exit 0.
- `kotoshu status --json` emits valid JSON (same StatusReport, second
  presenter).
- Code: `desc "status"` in `lib/kotoshu/cli.rb:267-287`; pure model at
  `lib/kotoshu/cli/status_report.rb` (no presentation logic).
- Spec: `spec/kotoshu/cli/status_report_spec.rb`.

Cosmetic caveat: the Thor `[WARNING]` stdout pollution noted in #28
also precedes status output.

## Problem
Users have no single command to see:
- What languages are set up (spelling, frequency, model)
- Cache disk usage
- Audit log location and size
- Whether semantic is available (onnxruntime loaded)
- Default language

`kotoshu setup --list` exists but is narrow. A dedicated `status` command
gives users a single thing to run when something goes wrong.

## Plan

### New command: `Kotoshu::Commands::StatusCommand`

Subclass of `Thor::Group` (or registered via `register` in the CLI).
Output:

```
Kotoshu 0.3.0

Setup:
  en   spelling  ✓  (~12 MB, cached 2026-06-27)
  en   frequency ✓  (~250 KB, cached 2026-06-27)
  en   model     ✓  (~114 MB, cached 2026-06-27)
  de   spelling  ✓  (~8 MB, cached 2026-06-25)

Cache:
  Path           /Users/user/.cache/kotoshu
  Size           142 MB
  Languages      2

Semantic:
  onnxruntime    loaded
  Active models  1 (en)

Other:
  Audit log      /Users/user/.local/share/kotoshu/audit.log (12 KB)
  Default lang   en
  Offline mode   no
```

### Implementation
- Reuse `ResourceManager.languages_setup`, `setup?`, etc.
- New helper `Kotoshu::Paths.cache_size` (sums `File.size` of all cached files).
- Honor `--json` flag for machine-readable output (single source of
  truth: same StatusReport model, two presenters).

### Status report model
`Kotoshu::Cli::StatusReport` — pure model. CLI formats to text; JSON
presenter emits structured output. MECE: model has no presentation.

## Acceptance

- [ ] `kotoshu status` works on a fresh install (shows empty setup).
- [ ] `kotoshu status` after `kotoshu setup en` shows the entry.
- [ ] `kotoshu status --json` emits valid JSON.
- [ ] Cache size is accurate to within 1 MB.
- [ ] Audit log path matches `Kotoshu::Paths.audit_log_path`.

## Dependencies
- #22 (SourceRegistry) — to show URLs.
- #25 (soft onnxruntime) — to report semantic availability.
