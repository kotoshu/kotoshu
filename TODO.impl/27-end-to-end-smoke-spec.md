# 27 — End-to-end smoke spec (T1, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `spec/integration/end_to_end_spec.rb` exists with the planned shape:
  fresh install → setup → use (setup `:downloaded`, `correct?`,
  misspelling rejection, `suggest` includes "the", document check),
  setup predicate, and two-stage `ResourceNotSetupError` enforcement —
  12 examples, tagged `:network`, isolated via tmp XDG dirs in an
  `around` hook.
- Run 2026-09-03: `NETWORK_TESTS=1 bundle exec rspec
  spec/integration/end_to_end_spec.rb` → 12 examples, 0 failures
  (real downloads from kotoshu/dictionaries).
- Real instances throughout; no `double()`. Excluded from the default
  run via the `:network` tag as planned.

## Problem
There is no spec that walks the actual install → setup → use path a real
user takes. Unit tests verify pieces; integration tests like
`walking_skeleton_spec.rb` use mocked or fixture data. Nothing catches
"this works end-to-end starting from an empty cache."

## Plan

### New spec: `spec/integration/end_to_end_spec.rb`

A single spec file with multiple examples covering the full path:

```ruby
RSpec.describe "Kotoshu end-to-end", :network do
  # Use temp XDG dir for full isolation
  around do |ex|
    Dir.mktmpdir do |dir|
      ENV["XDG_CACHE_HOME"] = "#{dir}/cache"
      ENV["XDG_CONFIG_HOME"] = "#{dir}/config"
      ENV["XDG_DATA_HOME"] = "#{dir}/local"
      Kotoshu::Configuration.reset
      ex.run
    end
  end

  describe "fresh install → setup → use" do
    it "sets up English spelling" do
      result = Kotoshu.setup(:en, want: %i[spelling])
      expect(result.spelling).to eq(:downloaded)
    end

    it "accepts a correctly-spelled word" do
      Kotoshu.setup(:en, want: %i[spelling])
      expect(Kotoshu.correct?("hello")).to be(true)
    end

    it "rejects a misspelling" do
      Kotoshu.setup(:en, want: %i[spelling])
      expect(Kotoshu.correct?("xyzzq")).to be(false)
    end

    it "suggests corrections" do
      Kotoshu.setup(:en, want: %i[spelling])
      expect(Kotoshu.suggest("teh")).to include("the")
    end

    it "checks a document and flags misspellings" do
      Kotoshu.setup(:en, want: %i[spelling])
      result = Kotoshu.check("this is a teh test")
      expect(result.misspelled_words.map(&:word)).to include("teh")
    end
  end

  describe "setup predicate" do
    it "returns false before setup" do
      expect(Kotoshu.setup?(:en)).to be(false)
    end

    it "returns true after setup" do
      Kotoshu.setup(:en, want: %i[spelling])
      expect(Kotoshu.setup?(:en)).to be(true)
    end
  end

  describe "two-stage model enforcement" do
    it "raises ResourceNotSetupError on cold correct?" do
      expect { Kotoshu.correct?("hello") }
        .to raise_error(Kotoshu::ResourceNotSetupError)
    end
  end
end
```

### Use `:network` tag
Already configured in `spec/spec_helper.rb` to only run when
`NETWORK_TESTS=1`. Run locally before release:
```
NETWORK_TESTS=1 bundle exec rspec spec/integration/end_to_end_spec.rb
```

### Real instances, no doubles
Per `~/.claude/CLAUDE.md`: no `double()` in specs. Use real cache, real
HTTP, real dictionaries.

## Acceptance

- [ ] `spec/integration/end_to_end_spec.rb` exists, all examples pass
      with `NETWORK_TESTS=1`.
- [ ] Spec isolates itself via temp XDG dirs (no pollution of dev cache).
- [ ] Spec uses real model instances, no `double()`.
- [ ] CI can run this on demand (network tag excludes from default run).

## Dependencies
- #23 (URL fix must land first so setup actually works).
