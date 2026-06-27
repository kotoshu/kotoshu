# 36 — Cleanup Regressions + 0.3.1 Bug-Fix Release

## Goal

Ship `kotoshu-0.3.1` — a focused bug-fix release that closes the
regressions introduced by the 0.3.0 lutaml-model migration and a small
set of pre-existing spec failures. This is the **only** Tier-1 work;
its acceptance criterion is a clean spec run on the non-network,
non-ONNX subset.

## Scope (locked)

| # | Failure cluster | Root cause | Fix shape |
|---|---|---|---|
| 1 | `spec/integration/walking_skeleton_spec.rb:22` — `result.suggestions.words` | Lutaml migration changed `WordResult#suggestions` from `SuggestionSet` to `Array<Suggestion>`. | Update spec to `result.suggestions.map(&:word)`. |
| 2 | `spec/integration/walking_skeleton_spec.rb:265` — `result.to_h` | Lutaml-model replaced hand-rolled `to_h`. The instance method is gone; framework supplies `to_hash`. | Update spec to call `result.to_hash` (lutaml-supplied). |
| 3 | `spec/kotoshu/suggestions/strategies/semantic_strategy_spec.rb` (22 failures) | Specs assume `onnxruntime` is installed and a model is loaded. Without ONNX, every example errors. | Tag the spec file `:onnx` and exclude by default; document the opt-in env (`ONNX_TESTS=1`) in CLAUDE.md. Mirror the `:network` opt-in pattern. |
| 4 | `spec/unit/hunspell/read_aff_spec.rb` (7 failures) | Real parser bugs in REP, MAP, PFX directive parsing and UTF-8 / numeric / long flag formats. | Fix each parser branch with a targeted spec; do **not** rewrite the whole reader. |
| 5 | `spec/kotoshu/language/detector_spec.rb:56` — Arabic detection | Pre-existing FastText LID gap. | Mark `pending` with a TODO referencing the upstream model; do not block the release on it. |
| 6 | `spec/benchmark/symspell_benchmark_spec.rb` (1 failure) | Likely environment-dependent timing. | Audit; if real bug, fix; if env noise, mark `:slow`. |

**Out of scope:** the 90+ `spec/integrational/{lookup,suggest}_spec.rb`
Hunspell-fixture failures. Those are T2 (`TODO.impl/37-hunspell-correctness-tier2.md`).

## Phase A — Lutaml regression cleanups

### A1. walking_skeleton_spec

- Line 28: `expect(result.suggestions.words).to include("hello")`
  → `expect(result.suggestions.map(&:word)).to include("hello")`
- Line 268: `hash = result.to_h`
  → `hash = result.to_hash` (lutaml-model supplies this)

### A2. semantic_strategy_spec gating

- Add `describe ..., :onnx do` or `RSpec.describe ... do; before { skip "set ONNX_TESTS=1" unless ENV["ONNX_TESTS"] } end`.
- Update `spec/spec_helper.rb` to exclude `onnx: true` unless `ONNX_TESTS=1`.
- Update `CLAUDE.md` "Notes" section to mention the opt-in.

### A3. Audit other lutaml fallout

- `grep -rn "\.suggestions\.words\|\.suggestions\.to_a\|\.to_h\b" spec/`
  (only the two walking_skeleton hits — confirmed.)
- `grep -rn "\.as_json\b" spec/` — already replaced in cli.rb; verify
  no spec calls the removed instance method.

**Acceptance:** `bundle exec rspec --tag ~network --tag ~onnx` shows
**0 failures** attributable to lutaml migration.

## Phase B — Hunspell .aff parser fixes

For each failing directive, add a focused spec covering the exact
shape from the failing fixture, then fix the parser branch.

### B1. REP directive (read_aff_spec:12)

Repairs — substitution pairs used by the suggester. Currently parsed
incorrectly.

### B2. MAP directive (read_aff_spec:31)

Character equivalence classes (e.g. `MAP uü`, `MAP aàáâã`). Sets up
related-character substitution in suggestions.

### B3. PFX directive (read_aff_spec:47)

Prefix rules. Currently fails to parse multi-rule PFX blocks. Likely
the same bug as SFX since they share the parser.

### B4. Long flag format (read_aff_spec:62)

`FLAG long` mode — two-character flags.

### B5. UTF-8 flag format (read_aff_spec:106)

`FLAG UTF-8` mode — flags are single Unicode codepoints.

### B6. Numeric flag format (read_aff_spec:125)

`FLAG num` mode — integer flags.

### B7. AF directive / flag aliases (read_aff_spec:125)

`AF` directive defines aliases used to keep `.dic` files compact.

**Acceptance:** all 7 `read_aff_spec` examples green; no regression in
existing `algorithms/` specs.

## Phase C — Pre-existing pending/skips

- Arabic detection: `pending "FastText LID missing Arabic vector — see TODO.impl/30-language-auto-detection.md"`.
- Symspell benchmark: audit; if real, fix; if env noise, `:slow`.

## Phase D — Cut 0.3.1

1. Bump `lib/kotoshu/version.rb` → `0.3.1`.
2. Update CHANGELOG (or create if missing).
3. Update README quickstart if it references any 0.3.0-broken API.
4. Run full suite (`bundle exec rspec --tag ~network --tag ~onnx`)
   green; `bundle exec rubocop` clean.
5. PR (not direct-to-main — see global rule).
6. After merge: tag `v0.3.1` (the **user** does this; never the agent).

## Release-level acceptance criteria

- `bundle exec rspec --tag ~network --tag ~onnx` → 0 failures
  (excluding the explicitly-pending FastText Arabic case).
- `bundle exec rubocop` → clean.
- Lutaml migration regressions: 0.
- Pre-existing Hunspell `.aff` parser bugs: 0.
- No new public API changes — 0.3.1 is strictly a bug-fix release.

## Dependencies

- **Blocked by:** nothing.
- **Blocks:** `TODO.impl/37-hunspell-correctness-tier2.md` (the next
  tier of Hunspell-fixture work).
