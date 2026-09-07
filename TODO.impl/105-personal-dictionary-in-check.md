# Plan 105 — The personal dictionary reaches the check path

## Why
`kotoshu personal add recieve` then `kotoshu check` still flags the word —
PersonalDictionary is wired only into the `personal` subcommand and the LSP
(resolved server-side), not into `Spellchecker#check`. Users who add words
see them flagged again on the very next run; the README story ("add words
you accept") is currently false on the CLI/API path.

## Work (gem repo)
1. `Spellchecker#check` consults the personal dictionary: a word present in
   personal.dic is not an error (mirror the LSP's semantics: filter at
   result assembly, keep suppression metadata out of the error rows).
2. Reload semantics: the LSP reloads on mtime change; the CLI/one-shot path
   loads once per process. Do not add hot reload here.
3. Opt-out: `Kotoshu.configure { personal_dictionary false }` (or the
   existing config seam — find it) and `--no-personal` on `kotoshu check`.
4. Specs: add-then-check round trip on a real dictionary; opt-out flags
   again; personal words still spellcheckable via suggest.
5. Docs truth: /docs/ignores gains the personal dictionary section (the
   action PR #2 README noted this gap) — deliver the copy in the PR body
   for the site follow-up, do not touch the site repo.

## Verification
Suite green (3,900+ examples); rubocop clean; `kotoshu personal add x &&
kotoshu check` live round trip recorded in the PR body.

## Status
Pending
