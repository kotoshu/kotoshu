# Plan 124 — Owner-gated residue (inventory, not executable by agents)

Status: standing inventory (updated 2026-09-10)

- VS Code Marketplace + Open VSX PATs → publish kotoshu-vscode
  (extension is publish-ready; owner: "later").
- ~~Worktree cleanup~~ — DONE 2026-09-12 under the owner's "make the
  needed cleanups now": every repo down to its single main worktree,
  merged branches deleted local+remote (see the memory entry).
- PyPI trusted publisher for kotoshu-native — owner registration
  (project kotoshu-native, owner kotoshu, repo kotoshu-rs, workflow
  release-pypi.yml, env blank), then rerun run 34681280341: the full
  16-wheel matrix + sdist are BUILT and preserved as artifacts; the
  publish step failed only on the missing registration.
- Typo layer registry cut — owner's three mechanical steps, runbooked
  in models-fasttext-onnx docs/RELEASING.md; the moment the pair
  carries vocab_url, `kotoshu setup LANG --typo` arms the layer.
- Gem 1.0.3 cut decision — main is ahead of 1.0.2 (opt-in typo layer,
  --typo setup, Windows strict-wrap fix, eager GVL-released build);
  nothing changes for default installs, so the cut timing and number
  are the owner's call.
- kotoshu-lsp: still 0.1.1 — joins a future train if the owner wants
  LSP on the 1.x line (audit train deliberately excluded it).
- Docker/kotoshu-ci + kotoshu-go/kotoshu-python floors: verify their
  gem/base pins resolve 1.x on their next cuts (same class of bug as
  plan 118 — check before, not after).
- rubygems 0.1.0 empties (lsp/server): support@rubygems.org deletion
  remains the only path; cosmetic, owner call.
