# 89 — Framework integrations (executes plan 62)

> [62-framework-integrations.md](62-framework-integrations.md) is the
> original plan — still Pending. This file is the wave-2 execution
> order; 62's design stands.

## What ships (inside the gem, soft-dependency style)

1. **Rails / ActiveModel validator** — `validates :body,
   spelling: true` (an EachValidator): checks the attribute with
   Kotoshu, adds one error per misspelling with the top suggestion.
   Config per-attribute: language, personal words. NO Rails
   dependency in the gemspec — the validator autoloads only when
   ActiveModel is defined (the onnxruntime/suika soft-dep pattern).
2. **RSpec matcher** — `expect_words("helo").to all_be_spelled_correctly`
   style plus a block matcher over a document; ships with proper
   failure messages.
3. **Rake task** — `kotoshu/check.rake`: checks changed markdown/
   asciidoc in the repo (uses the same file-selection as plan 88),
   wired via `gem 'kotoshu'` + `require 'kotoshu/tasks'`.
4. **Jekyll** — a generator plugin class checking posts/drafts,
   failing the build on new errors (respects baseline if present).

Each integration has specs that load the real framework pieces where
feasible (ActiveModel is loadable standalone in specs without Rails).

## What does NOT ship

Engine packaging, `kotoshu-rails` separate gem, Sidekiq batch
checkers — plan 62 phase 3, demand-gated.

## Status

**Pending.**
