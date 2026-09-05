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

**Pending.**
