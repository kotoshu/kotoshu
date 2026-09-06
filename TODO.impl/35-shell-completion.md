# 35 — Shell completion (T3, deferred past 0.3)

## Status
**Implemented** (2026-06-29). Shipped as `kotoshu completions bash|zsh|fish`
plus a `kotoshu completions languages` helper that the completion scripts
shell out to for dynamic language completion. README documents install
paths for each shell.

## Problem
CLI users want tab completion for `kotoshu <TAB>` → subcommands, and
`kotoshu setup <TAB>` → language codes.

## Plan (as implemented)

### `kotoshu completions <shell>`
Three Thor subcommands (`bash`, `zsh`, `fish`) emit a shell-specific
completion script. The scripts shell out to `kotoshu completions languages`
for dynamic language completion so newly registered languages appear
without re-running the install step.

### `kotoshu completions languages`
Prints every code from `Kotoshu::Language::Registry.supported_codes`,
one per line.

### Catalog
`Kotoshu::Cli::Completions::COMMANDS` is a static catalog of
`Command.new(name:, description:)` records. Descriptions are user-facing
and curated here (rather than introspected from Thor) so the completion
menu reads cleanly. `LANGUAGE_ARGUMENT_COMMANDS` lists the commands
whose first positional argument is a language code (currently
`setup`, `fetch`).

### Builders
`Kotoshu::Cli::Completions::ScriptBuilders::{Bash,Zsh,Fish}` are pure
template builders that take the catalog and render the shell-specific
script. They have no IO dependencies and are unit-tested in isolation.

### README install paths
[source,bash]
----
# bash (system)
kotoshu completions bash > /etc/bash_completion.d/kotoshu
# bash (user)
kotoshu completions bash > ~/.local/share/bash-completion/completions/kotoshu
# zsh
kotoshu completions zsh > "${fpath[1]}/_kotoshu"
# fish
kotoshu completions fish > ~/.config/fish/completions/kotoshu.fish
----

## Acceptance

- [x] `kotoshu completions bash|zsh|fish` emits valid scripts.
- [x] Installing the bash script enables `kotoshu <TAB>` to show subcommands.
- [x] `kotoshu setup <TAB>` offers language codes (via
      `kotoshu completions languages`).
- [x] README documents installation for each shell.

## Why deferred (originally)
Polish feature. Doesn't affect first-use or core spell-checking.

