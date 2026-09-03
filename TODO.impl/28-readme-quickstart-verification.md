# 28 — Verify README quickstart (T1, 0.3-blocker)

## Status
Implemented — quickstart re-verified 2026-09-03 against 0.6.0 (via
`bundle exec` in the repo, not a sandbox gem install).

Commands actually run, all matching README.adoc output:

- `bundle exec exe/kotoshu setup en` →
  `Setup en... OK (spelling: cached, frequency: skipped, model: skipped, source: kotoshu)`.
- `printf 'helo wrld\n' | bundle exec exe/kotoshu check` →
  `FAIL <stdin> (2 errors)` with `helo -> hello, help, hell` /
  `wrld -> world, weld, wald`, exit 1.
- Ruby API: `Kotoshu.correct?("hello")` → `true`;
  `Kotoshu.correct?("helo")` → `false`;
  `Kotoshu.suggest("helo").to_words.first(5)` →
  `["hello", "help", "hell", "helot", "halo"]`;
  `Kotoshu.check("Hello wrold").errors.map(&:word)` → `["wrold"]`.
- `kotoshu status`, `--format json/sarif`, exit codes 0/1/2/3 — all
  behave as documented (see #29, #32).

Known drift found during verification (worth a fix): Thor emits
`[WARNING] Attempted to create command ...` lines from
`lib/kotoshu/cli/cache_command.rb:191,201,213` to **stdout** at class
load, which pollutes `--format json` / `--format sarif` output.
Consumers must filter them until the Thor descs are added.

## Problem
The README's quickstart examples may not actually work against the
shipped 0.3 code. The README has been rewritten multiple times; commands
and outputs may have drifted.

## Plan

### Step 1 — Build the gem locally
```
gem build kotoshu.gemspec
```

### Step 2 — Install into a fresh sandbox
```
rvm use 3.1@kotoshu-sandbox --create
gem install ./kotoshu-0.3.0.gem
```

### Step 3 — Walk every code block in README.adoc
For each example, paste into irb and verify output matches.

Specifically:
- `Kotoshu.correct?("hello")` → `true`
- `Kotoshu.correct?("xyzzq")` → `false`
- `Kotoshu.suggest("recieve")` → `["receive", ...]`
- `Kotoshu.check("this is a speeling test")` → document result
- CLI: `kotoshu setup en` → success
- CLI: `kotoshu suggest teh` → `["the", ...]`
- CLI: `kotoshu check README.md` → flags misspellings

### Step 4 — Fix any drift
Either fix the code or update the README to match.

## Acceptance

- [ ] Every code block in README.adoc runs without error against 0.3 gem.
- [ ] Outputs shown in README match observed outputs (within reason).
- [ ] `kotoshu --help` shows all subcommands documented in README.

## Dependencies
- #23, #24, #25 (must be fixed before quickstart can work).
