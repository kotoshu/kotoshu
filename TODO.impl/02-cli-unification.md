# 02 — CLI Unification

## Goal

One canonical CLI surface that exposes every feature the gem supports, with
flags that match the README.

## Why

There are two competing implementations:

- `lib/kotoshu/cli.rb` — `Kotoshu::Cli::Cli < Thor`. This is what
  `exe/kotoshu` actually starts. Has only a basic `check TARGET` command
  and `dict`/`cache` subcommands.
- `lib/kotoshu/commands/check_command.rb` — `Kotoshu::CheckCommand < Thor`
  with `namespace :check`, exposes `--language auto`, `--interactive`,
  `--output`, `--format text|json|yaml|csv|sarif`, `--model fasttext|hunspell`,
  `--download`. **Not registered as a subcommand anywhere — dead code.**

The README advertises `--interactive`, `--format sarif`, `--model`,
`--language auto`. Users running `bundle exec exe/kotoshu check README.md
--interactive` get an "unknown option" error.

## Tasks

1. **Decide canonical location.** Recommendation: keep the rich
   `Kotoshu::CheckCommand` (it has all the features users want) and delete
   the basic `check` from `cli.rb`. Wire `cli.rb` to register
   `CheckCommand` via `subcommand "check", Kotoshu::CheckCommand` (or
   register at top level if `check` is the only command).
2. **Move `DictCommand` and `CacheCommand`** into `lib/kotoshu/commands/`
   alongside `CheckCommand` so all CLI commands live in one directory.
3. **Add a `model` subcommand** so users can manage ONNX models
   (`kotoshu model download en`, `kotoshu model list`,
   `kotoshu model validate`, `kotoshu model convert`). The README
   references these — they live in `lib/kotoshu/commands/model_command.rb`
   already; verify it's wired.
4. **Add `--from-stdin` mode** so the CLI can be used in shell pipes:
   `echo "wrold" | kotoshu check --from-stdin`.
5. **Reconcile flag names** between README and code. Specifically:
   - README says `--dictionary=unix_words`; `cli.rb` has both `--dictionary`
     and `--dictionary-path` — pick one.
   - README says `--output=json`; `CheckCommand` uses `--format=json
     --output=FILE` — clarify the two-flag split.
6. **Exit codes.** Define and document: 0 = clean, 1 = errors found, 2 =
   usage error, 3 = dictionary/model fetch failure. SARIF consumers
   (GitHub Code Scanning) require this contract.
7. **Help text audit.** Every Thor `desc` should match what's in the
   README, and the README should match what's in code.

## Acceptance criteria

- `bundle exec exe/kotoshu check README.md --interactive` works as
  documented
- `bundle exec exe/kotoshu check README.md --format sarif --output
  results.sarif` produces valid SARIF 2.1.0 that GitHub accepts
- `bundle exec exe/kotoshu --help` lists every command the README mentions
- No duplicate command classes; one canonical path per command
- A spec under `spec/kotoshu/cli/` exercises each subcommand end-to-end
  (using a temp dir, not real `~/.kotoshu`)

## Dependencies

- Light dependency on `03-dynamic-download` (CLI should let users
  pre-download resources), but can proceed independently.

## Out of scope

- LSP server, HTTP server (future work, not v1)
- GUI / TUI redesign — keep the existing Thor UX

## Status

_Pending._
