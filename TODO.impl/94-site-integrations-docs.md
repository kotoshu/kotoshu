# 94 — Site: integrations docs + directory mode + action truth

## Context

Wave 2 shipped features with zero site documentation: the Rails
validator, RSpec matchers, Rake task, Jekyll generator (gem PR #125)
and CLI directory mode (gem PR #124). The action page still says the
gem supports six languages.

## Job (site repo)

1. `/docs/integrations` — Rails (`validates :body, spelling: true`),
   RSpec matchers, `rake kotoshu:check`, Jekyll generator, pre-commit
   hook, GitHub Action — each example verified against the gem source
   (read lib/kotoshu/integrations* or wherever PR #125 landed them;
   run the rake task in a scratch dir if cheap).
2. CLI page: directory mode — `kotoshu check .`, known extensions,
   --include/--exclude, the gitignore subset (negation, globstar,
   anchoring), baselines interaction. Flags verified against
   `bundle exec exe/kotoshu check --help` in the gem repo.
3. Action page + install page: language lists updated to 19
   full-feature; action docs note directory mode (files: "." now
   walks the tree) and baseline usage.
4. News entry if the integrations wave was not already covered by a
   prior entry (check news.ts — the full-feature-19 entry exists;
   extend it or add "Framework integrations + directory mode").

## Status

**Pending.**
