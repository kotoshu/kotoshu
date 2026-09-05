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
checkers — plan 62 phase 3, demand-gated. (Also not shipped from 62
phases 1-2: the railtie, rails generator, dry-validation macro,
Capybara/Minitest helpers, ActionMailer preview checks.)

## Status

**Implemented 2026-09-05 (gem PR feat/framework-integrations).**
All four items shipped inside the gem on the soft-dependency
pattern (nothing new in kotoshu.gemspec; activemodel and jekyll are
dev-group test deps only):

1. `Kotoshu::Validators::SpellingValidator` — ActiveModel
   EachValidator; `validates :body, spelling: true` works after the
   documented one-line top-level alias (ActiveModel resolves helper
   validators from Object), `validates_with` works directly.
   language/personal_words options; one error per misspelling with
   the top suggestion. Specs load real ActiveModel standalone.
2. `Kotoshu::Rspec::Matchers` — expect_words + all_be_spelled_correctly,
   be_spelled_correctly (word or document), expect_document, with
   suggestion-bearing failure messages.
3. `Kotoshu::Tasks::CheckTask` — `require "kotoshu/tasks"` gives
   `rake kotoshu:check` over the repo text files via the plan-88
   selection (known extensions, .gitignore/.ignore, default skips);
   DSL: files/language/fail_on_error/baseline/root.
4. `Kotoshu::Jekyll::Generator` — safe generator checking posts and
   drafts, failing the build on new errors, respecting
   .kotoshu-baseline.json in the site source.

The rake task is require-only (defining a task on autoload would be
a surprise side effect); the others autoload from Kotoshu.
