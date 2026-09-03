# 24 — CLI auto-setup prompt (T1, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `lib/kotoshu/cli/auto_setup.rb` — `Kotoshu::Cli::AutoSetup` exactly as
  planned: non-TTY / offline → returns nil (no prompt); TTY → prints
  `Language 'en' is not set up (missing spelling). Download now (~5 MB
  from github.com/kotoshu/dictionaries)? [Y/n]`; on yes runs
  `Kotoshu.setup(language, want:)`.
- Wired in the CLI dispatcher: `lib/kotoshu/cli.rb:307-308` rescues
  `Kotoshu::ResourceNotSetupError`, delegates to `AutoSetup`, and
  re-raises as `Errors::ResourceUnavailable` (exit 3) when declined.
- Library API stays strict — only the CLI layer prompts.
- Spec: `spec/kotoshu/cli/auto_setup_spec.rb` — run 2026-09-03,
  0 failures. Exit code 3 is documented in the `check` long_desc and
  README.adoc ("language not set up").

Not re-verified interactively today (requires a TTY); the non-TTY and
prompt logic are spec-covered.

## Problem
Today:

```
$ kotoshu check README.md
# (stack trace from ResourceNotSetupError)
```

The library raises `ResourceNotSetupError` with a clear message — but
the CLI surfaces it as a stack trace. Users who install the gem and run
`kotoshu check` on day one don't know to run `kotoshu setup` first.

The two-stage setup/resolve split is correct for the **library** API
(see `lib/kotoshu/resource_manager.rb` — explicit setup, cache-only hot
path, no surprise downloads on metered networks). But the **CLI** should
be the friendly face.

## Plan

### Add `Kotoshu::Cli::AutoSetup` middleware

Catch `ResourceNotSetupError` in `Cli.start` (the existing dispatch
override, per project memory `kotoshu-cli-semantic-errors`). When caught:

1. Detect TTY. If non-TTY (piped output, CI), re-raise with the existing
   message — no surprise interactive prompts in scripts.
2. If TTY, prompt:
   ```
   Language 'en' is not set up (missing spelling).
   Download now (~5 MB from github.com/kotoshu/dictionaries)? [Y/n]
   ```
3. On yes: call `Kotoshu.setup(lang, want: %i[spelling])`, then retry
   the original command.
4. On no: exit 3 with the original message.
5. Honor `--offline` flag and `KOTOSHU_OFFLINE=1` env var — never prompt
   in offline mode, just exit with the error.

### Why this respects the two-stage model
The library API (`Kotoshu.correct?`, `Kotoshu.suggest`) still raises
strictly. Only the human-facing CLI adds the prompt layer. Programmatic
users get the strict behavior they need.

## Acceptance

- [ ] `kotoshu check file.txt` on a fresh cache prompts interactively.
- [ ] `echo "text" | kotoshu check -` (non-TTY) does NOT prompt — exits 3
      with the original error message.
- [ ] `KOTOSHU_OFFLINE=1 kotoshu check file.txt` does NOT prompt — exits 3.
- [ ] After "y" at the prompt, the check completes successfully.
- [ ] Existing CLI tests still pass; new spec covers the prompt path.

## Dependencies
- #23 (setup must actually work first)
