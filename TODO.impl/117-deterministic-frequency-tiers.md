# Plan 117 — Deterministic frequency tiers: stop the silent YAML fallback

Status: executed (gem PR #178, 2026-09-10)

Acceptance met: with the cache backdated past the TTL the compare is
2630/0/0 and suggest("ba") on the compoundrule fixtures returns the
frozen expectations exactly. conformance.yml gates the compare on
every push and PR; its first green run landed on the PR itself.
Suite 4007/0, rubocop clean. The checked-in-fixture variant of the
hermetic runner (design item 2) was not needed — the CI job seeds the
pinned cache instead; revisit only if the job proves flaky.

Depends on: plan 82 (conformance runner), the 2,630-vector contract (plan 66+)
Blocks: nothing — audit checklist item 7 is satisfied and CI-gated

## What happened (forensics, 2026-09-10)

Preparing the 1.0 train (checklist item 7) ran `rake
kotoshu:conformance:compare` on main:

    compare: 2630 vectors -- ruby failures: 16, native failures: 0, divergences: 16

All 16 failures are `suggest` vectors on the compoundrule{,2,3} fixtures:
same candidate words, same distances, different `confidence` values
(e.g. expected `b` = 0.952380952…, ruby = 0.8333333…).

Ruled out, with evidence:

- **Not plan 116 / not recent main.** v0.11.0 shows the identical 16
  failures; the suggestions/, dictionary/, core/ trees have zero commits
  between v0.9.2 and main.
- **Not the machine cache contents.** The downloaded Kelly `en.json`
  sha256 `97535823f41a3f0…` matches the pin in kotoshu-rs
  `suggest/frequency_data.rs` byte-for-byte; `load_cached` returns the
  same 47/185/907 tier sizes rust embeds.
- **Not an engine disagreement.** With a live (unexpired) cache:

      compare: 2630 vectors -- ruby failures: 0, native failures: 0,
      backend divergences: 0

### The actual mechanism

`Suggestions::FrequencyProvider` falls back
`FrequencyCache` → local YAML (`lib/kotoshu/data/common_words/en.yml`)
→ empty tiers. `BaseCache#available?` returns false when the metadata's
`cached_at` is older than the 7-day TTL. **The two datasets differ**:
the local YAML's top_50 contains `a` (bonus 200); Kelly's top_1000 is
where `a` lives (bonus 50). The bonus shifts one candidate's enhanced
score, the min–max normalization re-scales every confidence on the
tiny fixtures, and 16 vectors "fail".

So any machine whose frequency cache is absent or >7 days old silently
runs ruby on the YAML dataset — different suggestion ranking from the
frozen contract and from the Rust engine. This is a **user-facing
determinism bug**, not conformance bookkeeping: suggestion output
depends on cache age.

Two aggravators found on the way:

- `Kotoshu.setup(:en, want: [:frequency])` reported
  `frequency: :downloaded` but left `cached_at` at 2026-09-02 — either
  the re-download was skipped on checksum match (fine) and the
  timestamp was not refreshed (bug: guarantees later expiry), or the
  report is wrong. Verify and fix.
- Nothing CI-gates `conformance:compare` on the gem side (the rs repo
  gates its half only), which is why a two-week-old dataset switch was
  invisible.

## Fix design

1. **Expired ≠ unusable.** In `FrequencyProvider#load`, when
   `available?` is false but the on-disk cached data exists, load it
   anyway (`load_cached` does no network). TTL governs *refresh*
   (setup/`get` paths), never a silent switch to a different dataset.
   The YAML fallback then only serves machines with NO frequency data
   at all.
2. **Hermetic conformance.** The runner must not depend on machine
   cache state: check in the frozen Kelly tiers (the three sets +
   sha256, mirroring rs `frequency_data.rs`) as a conformance fixture
   and construct the engines with that provider data pinned. Then
   `conformance:compare` is deterministic on any machine, cache or no
   cache, and cross-verifies the fixture against the rs tables.
3. **CI gate.** Add an Ubuntu job: `rake compile && rake
   kotoshu:conformance:compare` on every push/PR. This invariant is
   the product's core correctness claim; it must not rely on someone
   remembering to run it.
4. **Setup timestamp.** When setup skips a download because the
   checksum matches, refresh `cached_at` (and report `:cached`).

## Acceptance

- `XDG_CACHE_HOME=<empty> rake kotoshu:conformance:compare` → 0/0/0
  (today it is 16/0/16; with a warm cache it is 0/0/0).
- Same on a machine with an expired cache (mock by backdating
  `cached_at`).
- New CI job green on main; suite unchanged otherwise; suggestion
  output for cache-cold machines now byte-identical to cache-warm
  ones on the fixture corpus.
- Explicitly out of scope: regenerating any vector. The 2,630 are
  correct; the data path was not.

## Surfaces

- `lib/kotoshu/suggestions/frequency_provider.rb`
- `lib/kotoshu/cache/base_cache.rb` (a load-explicit accessor if
  needed) and the setup refresh path
- `lib/kotoshu/conformance_runner.rb` (pinned provider)
- `conformance/fixtures/` (frozen tier fixture), `.github/workflows/`
  (compare job)
- specs for each behavior above
