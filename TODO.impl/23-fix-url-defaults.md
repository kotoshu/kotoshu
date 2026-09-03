# 23 — Fix URL + pin defaults so first-use doesn't 404 (T1, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence (all run 2026-09-03):

- `NETWORK_TESTS=1 bundle exec rspec spec/integration/end_to_end_spec.rb`
  → 12 examples, 0 failures — real download of `en` spelling from
  `kotoshu/dictionaries` into an isolated tmp XDG home; setup returns
  `:downloaded`, `correct?("hello")` true, `suggest("teh")` includes
  `"the"`. No 404s.
- Live German acceptance, isolated tmp XDG home:
  `Kotoshu.setup(:de, want: %i[spelling]).spelling` → `:downloaded`.
- Root cause fixed structurally: dictionaries default pin is `v1` in
  `SourceRegistry::SOURCES[:spelling]` (`lib/kotoshu/source_registry.rb:22`).

The `en`/`de` correct?/suggest acceptance items were also exercised
through the real dev cache via the README quickstart (see #28).

## Problem
Today `Kotoshu.setup(:en)` fails:

```
$ KOTOSHU_OFFLINE=0 bundle exec ruby -e 'Kotoshu.setup(:en)'
# => 404 from raw.githubusercontent.com/kotoshu/dictionaries/main/...
```

Two causes:
1. `dictionaries_url` default ends in `/main` but the dictionaries repo
   default branch is `v1`.
2. `resource_pin` default is `main` regardless of repo.

## Plan

### Step 1 — Implement TODO #22 (`SourceRegistry`)
Done first.

### Step 2 — Update default pin for dictionaries to `v1`
Via `SourceRegistry::SOURCES[:spelling].default_pin = "v1"`.

### Step 3 — Verify end-to-end
```ruby
Kotoshu.setup(:en, want: %i[spelling]).spelling # => :downloaded
Kotoshu.correct?("hello")                       # => true
Kotoshu.suggest("teh").include?("the")          # => true
```

## Acceptance

- [ ] Live run of `Kotoshu.setup(:en)` returns `:downloaded` (not 404).
- [ ] Live run of `Kotoshu.setup(:de)` returns `:downloaded`.
- [ ] `Kotoshu.correct?("hello")` returns `true` after setup.
- [ ] `Kotoshu.suggest("teh")` returns a list that includes `"the"`.

## Dependencies
- #22 (SourceRegistry)
