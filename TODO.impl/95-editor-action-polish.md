# 95 — Editor + action polish

## A — kotoshu-vscode: delegate add-to-dictionary

The extension's client-side write + "diagnostics stay until the
server adds support" message are now stale: kotoshu-lsp PR #3 added
the server-side `kotoshu.addToPersonalDictionary` command WITH
republish. Update the extension to execute the server command (via
the language client's executeCommand), falling back to the local
write if the server is older; fix the message; refresh the README
note. Smoke test in CI still passes (server built from source there).

## B — action-kotoshu truth

- action.yml language description says six languages — now 19.
- Add an optional `baseline` input passing `--baseline` through
  (directory mode makes the action a whole-repo checker; baselines
  are its natural companion). README examples updated.

## Status

**Implemented (2026-09-05, action PR #1 + kotoshu-vscode PR #2).**
Action: language input truth + next-release docs (the published 0.7.0
gem still gates six languages - directory mode/baselines/19 langs
ride the next gem cut). VS Code: add-to-dictionary delegates to the
server command (with republish) when advertised, local-write
fallback otherwise.
