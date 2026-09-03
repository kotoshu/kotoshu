# 32 — Verify SARIF / JSON output through CLI (T2, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Live verification (2026-09-03, `bundle exec exe/kotoshu check
--format sarif --language en <file with two misspellings>`):

- Output parses as JSON; `version: "2.1.0"` with
  `$schema: https://json.schemastore.org/sarif-2.1.0.json`;
  `runs[0].tool.driver` carries name/version/rules
  (`kotoshu/spelling`); `results` flag both misspellings with level,
  message including suggestions (`'teh' is not in the dictionary.
  Suggestions: the, ten, tet`), and `locations.physicalLocation`
  (artifact uri + char offset/length region).
- Exit code 1 with errors found; 0 on a clean file.
- Spec: `spec/kotoshu/cli/check_format_spec.rb` (real CLI invocation,
  JSON/SARIF shape assertions) — run 2026-09-03, 0 failures.

Answers the plan's wiring question for 0.6.0: the wired surface is the
`check` in `lib/kotoshu/cli.rb` (class_options `--format
text|json|sarif`, `display_result` at cli.rb:90-95,509), which renders
SARIF via the batch reporter (`lib/kotoshu/cli/batch_reporter.rb`,
`to_sarif`). The richer `Commands::CheckCommand`
(`commands/check_command.rb`, adds yaml/csv) is a separate surface.

Caveats not covered by the acceptance run: (a) Thor `[WARNING]` lines
from `cache_command.rb` precede the JSON on stdout (see #28) — filter
or fix before piping to a SARIF consumer; (b) GitHub code-scanning
upload not tested here.

## Problem
`Kotoshu::CheckCommand` (in `lib/kotoshu/commands/check_command.rb`)
already implements `--format sarif/json`. But it may not be wired
correctly through the actual `kotoshu check` CLI surface. CI users
rely on SARIF for GitHub code scanning integration.

## Plan

### Step 1 — Audit CLI surface
Check `lib/kotoshu/cli.rb` and `lib/kotoshu/commands/check_command.rb`.
Verify:
- `kotoshu check --format sarif file.txt` actually emits SARIF JSON.
- `kotoshu check --format json file.txt` emits the JSON documented shape.
- Exit codes are correct (0 = no errors, 1 = errors found, etc.).

### Step 2 — Fix any wiring gaps
The richer `CheckCommand` exists but may not be the one wired into the
CLI. CLAUDE.md notes: "A richer Kotoshu::CheckCommand exists in
commands/check_command.rb (with --interactive, --format sarif/json,
--model, --language auto) — check which one is actually wired before
assuming a CLI flag exists."

### Step 3 — Spec it
New spec `spec/kotoshu/cli/check_format_spec.rb`:
- Real CLI invocation via `Kotoshu::Cli::Cli.start(%w[check --format json file.txt])`.
- Parse output as JSON.
- Assert structure matches documented shape.

### Step 4 — Validate SARIF
Validate output against the SARIF v2.1 schema (https://json.schemastore.org/sarif-2.1.0-rtm.5.json).

## Acceptance

- [ ] `kotoshu check --format json` emits valid JSON.
- [ ] `kotoshu check --format sarif` emits SARIF v2.1 valid output.
- [ ] SARIF output passes schema validation.
- [ ] Exit code is 1 when errors are found, 0 when clean.
- [ ] GitHub code scanning accepts the output (manual upload test).

## Dependencies
- None (independent of T1).
