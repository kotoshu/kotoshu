# 97 — Executes plan 59: YARD API documentation published

## Context

Plan 59 has been Pending since before the campaign: the gem is the
primary audience surface for Ruby developers, its public API is
large (facade, Spellchecker, two-stage ResourceManager, tiers,
baselines, integrations), and there is NO published API reference —
no .yardopts, no docs CI, coverage gaps everywhere.

## Job

1. `.yardopts` (markup markdown, the right --title, exclude
   spec/tasks; default rule set).
2. **Coverage pass** on the PUBLIC surface only (no internals
   archaeology): the `Kotoshu` module facade (kotoshu.rb), Cli,
   Spellchecker, ResourceManager/Bundle/SetupResult, Configuration,
   Paths, Documents + Suppressions, PersonalDictionary, Baseline,
   Suggestions::Generator strategies' public constructors, the
   integrations entry points (validator/matchers/tasks/jekyll —
   these are what users paste into their apps). Every public method:
   @param/@return/@example where non-obvious; examples must be ones
   that would run. `bundle exec yard stats` driven to a stated
   coverage number on the public list; undocumented ratio printed.
3. **CI**: a `docs` workflow building `yard doc` as an artifact on
   main (cheap job). HOSTING decision (gh-pages vs a subpath on
   kotoshu.github.io) is an owner choice — do not deploy anywhere;
   record the two options in the plan Status for the owner.
4. Cross-link: README.adoc "API documentation" section pointing at
   wherever the owner decides to host (placeholder link text for now).

## Constraints

Docstring work must not change runtime behavior — comments and
declarations only. Suite stays 3701/0/27.

## Status

**Pending.**
