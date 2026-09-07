# Kotoshu Stability Policy — 1.0 draft

Status: DRAFT (plan 109). Takes effect the day 1.0 ships; until then the
usual 0.x rules apply (anything may change). The surface this policy
protects is itemized in `docs/STABILITY-1.0-AUDIT.md`.

## Principles

1. Semver, per delivery vehicle, cut together on one release train.
2. Additive changes only, within a versioned boundary (`/v1`,
   `kotoshu.resources/v1`, the four-key suggestion row).
3. Behavior is frozen where the conformance vectors freeze it — the
   vectors ARE the behavioral contract.
4. No removal without a deprecation window (below).
5. The strict two-stage resource model is permanent: `setup` is explicit,
   the hot path never downloads. No feature may weaken it.

## Per-surface commitments

### Ruby gem (`kotoshu`)

- **Patch** (1.0.x): bug fixes only. No public API, CLI, ENV, output, or
  conformance-vector change. `conformance/vectors.jsonl` must replay
  byte-identically (`lib/kotoshu/conformance_runner.rb:72`).
- **Minor** (1.x): additive only — new methods, new config keys (must
  default to current behavior), new CLI flags with defaults, new
  exception subclasses of existing roots, new suggestion strategies.
  Frozen in place: existing method signatures, the exception class list
  at `lib/kotoshu/core/exceptions.rb`, `SCHEMA` key semantics
  (`lib/kotoshu/configuration.rb:38`), exit codes 0/1/2/3
  (`lib/kotoshu/cli.rb:92-97`), and the JSON/SARIF output shapes
  (`lib/kotoshu/cli.rb:624-651,686-715`) — additions to JSON output are
  allowed (consumers must ignore unknown keys), renames and removals are
  not.
- **Major** (2.0): anything else, including conformance-vector re-exports
  that change expected results.
- Ruby floor moves only at a major (`kotoshu.gemspec:17`).
- Requirements and dependency floors are owner decisions, never inferred
  from code findings.

### wasm package (`@kotoshu/wasm` / kotoshu-rs)

- Independent version line (its `package.json` governs, not the crate
  constant — `kotoshu-rs/kotoshu/src/ffi/wasm/mod.rs:149-155`), released
  on the same train as the gem.
- The JS surface is the module doc contract:
  `KotoshuWasm` (constructor / `correct` / `suggest` / `VERSION`),
  `loadModel`, `rerank`, `semanticSuggest`, `loadLid`, `detectLanguage`,
  and the `KotoshuModel` / `KotoshuLid` handles
  (`kotoshu-rs/kotoshu/src/ffi/wasm/mod.rs:19-46`).
- The suggestion row is frozen at exactly `word`, `distance`,
  `confidence`, `source` — the conformance `SUGGESTION_KEYS`
  (`lib/kotoshu/conformance_exporter.rb:80`). Additive optional
  parameters are allowed (the `bucketsBytes` third argument of
  `loadModel` is the precedent, mod.rs:215-219); changing existing
  parameters or return shapes is a major.
- `KotoshuWasm.VERSION` tracks the crate version; it is informational,
  not the package version.

### HTTP server (kotoshu-server)

- `openapi.yaml` is the source of truth; `lib/kotoshu/server/app.rb`
  must never diverge from it (today they match route for route).
- The `/v1` prefix IS the contract version. Within `/v1`: new endpoints,
  new optional request fields, and new optional response fields are
  minor. Changing a field type, removing a field, altering status-code
  semantics (400/422/503), or mutating a frozen schema is a major —
  breaking changes ship as `/v2`, with `/v1` kept for the deprecation
  window.
- Error bodies keep the `{error, message, hint}` shape
  (`kotoshu-server/openapi.yaml:246-251`).

### GitHub action (action-kotoshu)

- Inputs are additive-only and every new input defaults to the previous
  behavior (`action-kotoshu/action.yml:8-59`). Outputs
  (`sarif-path`, `error-count`) are frozen.
- Bumping the gem floor (`version` input minimum, action.yml:98-105) or
  dropping an input is a new action major. Exit-code mapping 0/1/2/3 is
  part of the contract (action.yml:178-189).

### Resource registry (models-fasttext-onnx)

- The spec string `kotoshu.resources/v1` is frozen
  (`schemas/registry.schema.json:15-17`). Any schema change to the
  registry shape means `kotoshu.resources/v2`, consumed side by side.
- Resource ids are permanent and never reused; artifact content changes
  bump `release_tag` and `registry_version`, never the id (schema
  description, registry.schema.json:5).
- `min_engine_version` is the compatibility lever for old gem versions
  reading a newer registry — raising it requires a coordinated release
  note.

### Conformance vectors (the behavioral contract)

- `conformance/vectors.jsonl` (2630 rows) freezes what the engines
  ACTUALLY return over the fixture corpora — Ruby and native must both
  replay it identically (`lib/kotoshu/conformance_runner.rb:97-112`).
- A patch release MUST NOT change any vector. A minor may add vectors
  (new corpora/words) but not change existing expectations. Changed
  expectations = changed user-visible suggestions = major, with a
  CHANGELOG entry listing affected inputs.
- Re-export procedure stays as documented: deterministic export
  (`lib/kotoshu/conformance_exporter.rb:44-53`), commit to this repo,
  kotoshu-rs syncs from it (conformance_exporter.rb:54-60).

## Deprecation window

Proposal: **two minor releases** (the standard the ecosystem already
drifted toward — `fetch` and `dictionaries_url` both wait indefinitely;
1.0 is the moment to make it finite).

- Ruby API: YARD `@deprecated` tag + a `Kernel#warn` (once per process)
  from the moment of deprecation; removal at the second subsequent
  minor, or at the next major, whichever comes first.
- Constants/autoloads (e.g. the alias constants at `lib/kotoshu.rb:80-85`):
  same window; `autoload` removal is the deletion.
- CLI: the command/flag stays functional but hidden from help, printing a
  stderr deprecation notice with the replacement; removal after two
  minors. Exit codes do not change during the window.
- ENV/config keys (`KOTOSHU_*`): warn on read for two minors, then remove.
  ENV removals are called out in the changelog header — they break CI
  setups silently otherwise.
- HTTP: a deprecated field/endpoint returns `Deprecation`/`Sunset` style
  headers during the window; `/v1` keeps serving it until `/v2` has been
  stable for one minor.
- Exception: anything already deprecated throughout late 0.x (the `fetch`
  alias, `dictionaries_url`/`models_url`) may be removed AT 1.0 without a
  new window — the 0.x line was the window.

## The 1.0 gate

1.0 ships when the audit checklist in `docs/STABILITY-1.0-AUDIT.md` is
cleared: deprecation dispositions landed, the release train (gem + wasm +
server) coordinated, conformance compare green on both engines, and this
policy approved by the owner. Version numbers, floors, and the cut date
are owner decisions — this document proposes, the owner disposes.
