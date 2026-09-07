# Plan 104 — VS Code marketplace + Open VSX readiness

## Why
The extension is built, CI-green, with a .vsix artifact — but it is not
installable without the marketplace listing, which is the single largest
adoption blocker for the editor audience. Publishing needs the owner's
publisher PAT (a credential we never hold); everything else can be ready
so publishing is one secret + one click.

## Work (vscode repo)
1. Open VSX publish workflow (release-ovsx.yml, secret-gated) beside the
   existing CI — Open VSX serves VSCodium/Code-OSS users without the
   Microsoft marketplace.
2. Metadata polish: gallery banner/colors, keywords, categories, repository
   links, the kotoshu-vscode README (quickstart with kotoshu-lsp install,
   settings reference: log level, personal dictionary command).
3. PREPUBLISH.md: exact owner steps — create publisher, add PAT as secret,
   run the workflow; nothing else.
4. Site follow-up line (rides plan 99's pass): /docs/clients/lsp gains the
   marketplace link placeholder to fill on publish day.

## Verification
`vsce package` clean with no warnings; workflow lint-valid; PREPUBLISH
steps verified against the actual GitHub UI labels.

## Status
Pending
