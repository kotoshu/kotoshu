# 98 — Campaign cleanup: inventory, executed items, and approvals

> Asked by the owner 2026-09-06: "What is the clean up like?" after
> five waves (plans 77–97) and the release day. This file is the
> record: what was cleaned, what needs an explicit yes, and what is
> deliberately kept.

## Executed (non-destructive)

- The 34 untracked TODO.impl plan files (01–11, 20–76 era) committed
  to the gem repo — the plan corpus is finally fully tracked.
- This plan file itself.

## Keep (actively in use)

| Item | Why |
|---|---|
| `kotoshu/.claude/worktrees/pr93` | PR #139 is OPEN awaiting owner review |
| `kotoshu` main checkout untracked files (examples/, docs/, scripts/, test_*.rb — ~90 files) | The owner's pre-campaign material; not mine to commit or delete |
| `fork` remote in the gem main checkout | Points at the #93 contributor's fork; harmless, useful if follow-ups |

## Proposals awaiting explicit approval (destructive)

1. **~214 GB of models-repo worktrees** — the big one.
   `batch2` 121 GB + `expand` 73 GB + `nb` 13 GB + `mirrors` 7.2 GB +
   `agent-71` 280 MB. Contents: fastText `.vec.gz`/`.vec` source
   archives (re-downloadable from the CDN; every shipped artifact
   lives in LFS + release assets, sha-verified at each release) plus
   merged working copies. Disposition: `git worktree remove` +
   delete. Nothing irreplaceable; ~200 GB reclaimed.
2. **16 merged/stale worktrees** across gem (2b, two agent-*, correct3,
   features, wave2, yard, an empty kotoshu-rs dir), kotoshu-rs
   (wasm-models, wheels), site (adoption, flip, integrations, news6,
   rerank, truth2) — ~2 GB, mostly node_modules. Verification scratch
   inside three of them (correct3/scratch, adoption/spike = CDP
   scripts, truth2/.verify) gets relocated to
   `docs/verification-evidence/` in each repo BEFORE removal.
3. **The `2b` reference branch** (fix/t2-phase2b-compounding — the
   alternate T2-2B implementation kept for comparison). Options:
   keep as-is, or preserve its tip as a local tag
   (`t2-phase2b-reference`) and then remove the worktree.
4. **Local merged branches** in each repo (rebase-merge leaves the
   local copies behind): `git branch -d` list per repo — merged-only,
   reflog-recoverable.

## Deliberately NOT proposed

- Yanking the two empty 0.1.0 gems — happens right after their 0.1.1s
  land (owner registrations pending).
- The ~184 GB figure quoted earlier understated: the true worktree
  footprint is ~216 GB (214 models + ~2 elsewhere).
- `~/.gem/credentials`, `~/.cargo/credentials.toml`, `~/.pypirc` —
  never touched.

## Status

**Executed (2026-09-06, owner approved all + rebase-merge).**

- PR #139 (the rescued #93 work) rebase-merged: remove_word corruption,
  PlainText length-index sync, threshold fix, cache-only hot path,
  KOTOSHU_OFFLINE env fix — suite 3751/0.
- Models worktrees (batch2/expand/nb/mirrors/agent-71, ~214 GB
  re-downloadable source archives) removed; worktree table pruned.
- All campaign worktrees removed across gem/rs/site (two were locked
  by long-dead agent pids — unlocked first); verification scratch from
  correct3 preserved in docs/verification-evidence (PR #142; cached
  dictionaries excluded). The truth2 `.verify` turned out to be a
  Chrome profile dir, not scripts — not preserved, deleted with its
  worktree; adoption spike scripts were one-shot probes, findings live
  in plan 78's status.
- `2b` reference tip preserved as LOCAL tag `t2-phase2b-reference`
  (not pushed — tags are owner actions); worktree + merged branches
  deleted.
- Merged local branches deleted per repo via `git branch -d` only.
  The SHA-diverged rebase-merged campaign branches (content verified
  on main via --cherry-pick) and pre-campaign user branches are LEFT
  IN PLACE — force-deleting them was not what was approved.
- Disk: models .claude/worktrees now 0 B.
