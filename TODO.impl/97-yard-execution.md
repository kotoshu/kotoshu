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

**Merged (PR #NNN — filled at merge).**

What shipped:

- `.yardopts`: title "Kotoshu API Reference", markup markdown,
  README.adoc as the readme, excludes for `^spec/`, `^tasks/`,
  `^ext/`, `^conformance/`, `--hide-void-return` (pragmatic default:
  no hard undocumented-count rule).
- Coverage pass on the full public list (facade, Cli, Spellchecker,
  ResourceManager/Bundle/SetupResult, Configuration, Paths, Documents
  + Suppressions, PersonalDictionary, Baseline, Suggestions::Generator,
  integration entry points). Undocumented objects in the covered
  files: 28 before, 0 after; repo-wide 84.72% -> 85.80%. Broken tag
  warnings (`@param` name mismatches etc.) fixed repo-wide so the CI
  gate can start green — includes small docstring-only fixes in
  internals (cspell, metrics_collector, language_cache, strategies,
  pattern matchers, embedding pipeline).
- CI: `.github/workflows/docs.yml` — yard doc on main + PRs touching
  `lib/**`/`.yardopts`/README, uploads `doc/` as the `yard-docs`
  artifact, fails on warnings indicating broken tags (unknown/duplicate
  parameter names, unknown or malformed tags). Unresolved prose links
  in internal namespaces are known debt (~30 sites) and do not gate.
- README.adoc gained an "API Documentation" section.

HOSTING — owner choice, nothing deployed yet:

1. **gh-pages off this repo** — the docs workflow gets a deploy step
   publishing `doc/` to the `gh-pages` branch. Zero new moving parts,
   everything lives in this repo; URL becomes
   `kotoshu.github.io/kotoshu`.
2. **Subpath on kotoshu.github.io** — the site repo owns the single
   public host and links `/api/` to the reference. YARD's output uses
   relative links so it works under a subpath unchanged; costs a small
   sync job (artifact download or subtree copy) plus a site-repo PR
   per doc rebuild.
