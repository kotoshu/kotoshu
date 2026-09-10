# Plan 124 — Owner-gated residue (inventory, not executable by agents)

Status: standing inventory (updated 2026-09-10)

- VS Code Marketplace + Open VSX PATs → publish kotoshu-vscode
  (extension is publish-ready; owner: "later").
- Worktree cleanup — ASK OWNER before removing anything:
  gem `.claude/worktrees/*` (10+ campaign worktrees), kotoshu-rs
  `.claude/worktrees/packs` (content already merged), and /tmp
  worktrees from the 1.0 day: fix-baseline, gem-dogfood, plan-116,
  impl-116, impl-117, conf-0110, conf-0100, conf-092, conf-4597,
  wasm-10, plans-118.
- kotoshu-lsp: still 0.1.1 — joins a future train if the owner wants
  LSP on the 1.x line (audit train deliberately excluded it).
- Docker/kotoshu-ci + kotoshu-go/kotoshu-python floors: verify their
  gem/base pins resolve 1.x on their next cuts (same class of bug as
  plan 118 — check before, not after).
- rubygems 0.1.0 empties (lsp/server): support@rubygems.org deletion
  remains the only path; cosmetic, owner call.
