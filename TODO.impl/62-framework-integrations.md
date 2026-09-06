# 62 — Framework integrations (Rails, static-site generators, test suites)

Promotes the Ruby-ecosystem integration idea into a promotable plan.

## Goal

Kotoshu is a Ruby library first. Make it idiomatic inside the Ruby
ecosystem so a Rails app, a Jekyll site, or an RSpec suite can opt into
spell-checking in one line.

Three integration surfaces, all shipped **inside the library gem** (not
in separate repos — these are pure Ruby, no packaging overhead):

1. **Validation layer** — ActiveModel validators and equivalents that
   fail on misspelled content at model save time.
2. **Build-time check** — Rake tasks for static-site generators
   (Jekyll, Bridgetown, Middleman, Hugo via shell-out) so a misspelled
   post fails the build.
3. **Test helpers** — RSpec custom matchers and a Capybara integration
   for system-test assertions on rendered text.

## Why

The library API (`Kotoshu.correct?`, `.check`) is correct but generic.
Each Ruby framework has its own idioms — Rails has `ActiveModel::Validator`,
Jekyll has `:site, :post_write` hooks, RSpec has its matcher protocol.
Without framework-native entry points, users either skip spell-checking
or reinvent the wrapper.

A one-line `validates :body, kotoshu: true` in a Rails model is the
difference between "everyone on the team checks spelling" and "nobody
does." Same for `rake kotoshu:check` in a Jekyll site's deploy pipeline.

## Tasks

### Phase 1 — ActiveModel validator (Rails / Hanami / AnyModel)

1. **`Kotoshu::Rails::EachValidator`.** Register as
   `validates :body, kotoshu: true`. Options:
   - `language:` — overrides auto-detection (default: auto).
   - `personal_dictionary:` — path or `false` to disable.
   - `ignored:` — array of words to skip.
   - `suggestions:` — include suggestions in the validation error
     message (default true).
2. **Railtie.** Auto-register the validator on Rails boot when
   `defined?(::Rails)`. Lazy — non-Rails apps pay nothing.
3. **Generator.** `rails g kotoshu:install` writes a `.kotoshu.yml`
   scaffold and an initializer that pre-warms the default language on
   boot (configurable, off by default to avoid blocking boot).
4. **Hanami / Dry-Validation contract.** Document the Dry-Validation
   macro pattern; ship a `Kotoshu::Dry::Predicate` users import into
   their contracts.
5. **Sinatra / Roda** — a `before` filter recipe in the README; no
   framework-specific code needed.

### Phase 2 — Static-site generator rake tasks

6. **`Kotoshu::RakeTask`.** Reusable rake task with config DSL:
   ```ruby
   Kotoshu::RakeTask.new do |t|
     t.files = FileList["_posts/**/*.md", "_pages/**/*.md"]
     t.language = "en"        # or :auto
     t.fail_on_error = true
     t.format = :text         # or :sarif, :json
   end
   ```
   Generates `rake kotoshu:check`.
7. **Jekyll integration.** Auto-detect `_config.yml` and register the
   rake task. Optionally a Jekyll `:site, :pre_render` hook that
   spell-checks each rendered page in development (off in production
   to avoid slowing the build).
8. **Bridgetown / Middleman.** Document the rake task invocation; no
   gem-level integration unless there's a plugin API worth hooking.
9. **Hugo / Eleventy / Zola.** Shell-out recipe in the README; the
   rake task is language-agnostic, the site generator is irrelevant.

### Phase 3 — Test helpers

10. **RSpec custom matcher `be_well_spelled`.**
    ```ruby
    expect(rendered_page).to be_well_spelled
    expect(user.bio).to be_well_spelled(in: "en")
    ```
    Failure message lists the misspelled words with suggestions.
11. **Minitest matcher** (mirrors RSpec) so Rails default tests work.
12. **Capybara system-test integration.** `page.assert_no_spelling_errors`
    runs Kotoshu against the rendered DOM text (excluding `<script>`,
    `<style>`, `<input>` values). Options for allowlist selectors
    (e.g. skip `[contenteditable]` blocks).
13. **ActionMailer / ActionView preview check.** A test helper that
    spell-checks rendered email previews; catches typos in transactional
    copy.

### Phase 4 — Packaging

14. **All of the above inside `lib/kotoshu/rails/`, `lib/kotoshu/rake/`,
    `lib/kotoshu/rspec/`, `lib/kotoshu/minitest/`,
    `lib/kotoshu/capybara/`.** Lazy-loaded via autoload; users who
    don't `require 'kotoshu/rails'` pay no cost.
15. **`kotoshu.gemspec` soft-deps.** Rails, Jekyll, RSpec, Minitest,
    Capybara are NOT runtime deps. Code paths guard on
    `defined?(::Rails)` etc. so the gem still installs on slim
    environments (consistent with the soft-dep policy for onnxruntime
    and suika — see CLAUDE.md).
16. **Examples** in `examples/` for each integration
    (`examples/30_rails_validator.rb`,
    `examples/31_jekyll_rake_task.rb`, etc.).

## Acceptance criteria

- A fresh Rails 7 app with `gem "kotoshu"` and
  `validates :body, kotoshu: true` rejects a misspelled `body` on save.
- A fresh Jekyll site with the rake task fails `rake kotoshu:check` on
  a misspelled post.
- An RSpec spec with `expect(text).to be_well_spelled` fails on
  misspelled text and the failure message includes suggestions.
- All framework code is autoloaded; `Kotoshu.correct?` latency is
  unchanged in apps that don't use the framework integrations.
- Each integration has its own spec under `spec/kotoshu/rails/`,
  `spec/kotoshu/rake/`, etc. Specs use real framework instances
  (no doubles — global rule).

## Dependencies

- **Blocked by:**
  - `02-cli-unification` — the rake task wraps the CLI; clean library
    API is required
  - `50-structure-aware-document-api` — for accurate positions in
    Markdown content
- **Blocks:** nothing directly; ecosystem multiplier for adoption.
- **Cross-repo:** none — these live inside the library gem.
- **Promotes from:** implied by the "make it work for every Ruby
  project" thread of the vision (`00-vision.md`).

## Out of scope

- Non-Ruby frameworks (Django plugins, Express middleware, Laravel
  validators). Those need HTTP API clients — see `64-http-api-and-sdks.md`.
- Spelling fixes as part of the Rails request cycle (in-request
  rewriting of submitted content). That's a content-sanitization
  decision the application should own.
- Auto-rewriting static-site posts. Surfaces the suggestion; the author
  decides. Same policy as the CLI's `--interactive` mode.

## Risks

- **Framework version drift.** Rails / RSpec / Minitest APIs change.
  Pin tested versions in `Appraisals` (or equivalent); run integration
  tests against the matrix.
- **Boot-time cost.** A Railtie that pre-warms dictionaries on boot is
  a footgun. Default off; document the tradeoff loudly.
- **Test-suite speed.** Running Kotoshu on every Capybara screenshot is
  slow. Make it opt-in per-test (`scenario "renders correctly", :spell
  do`) rather than blanket-on.

## Status

_Pending._ Phase 1 + 2 is a coherent 0.4-shippable unit; phase 3 is
0.4+ depending on community demand signal.
