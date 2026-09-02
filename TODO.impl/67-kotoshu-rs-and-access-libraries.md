# 67 — Publishing the Stack: Tiered Models, kotoshu-rs, Access Libraries

The delivery train for [65-universal-kotoshu.md](65-universal-kotoshu.md):
turns plans 66 (Rust core), the models-repo plans 06/07 (tiers,
registry, releases) into a sequenced rollout of **what gets published,
from which repo, in what order**. Execution-level: each milestone has
one owner repo, a concrete deliverable, and acceptance.

## The train

```
M0 spec freeze ─► M1 gem tier client ─► M2 models release ─┐
 (registry v1)                                    (owner    │
                                                  tags)    ├─► M5 shims
M3 kotoshu-rs P0 (bootstrap) ─► M4 P1–P2 port ────────────┘     (ruby/wasm/python)
                                                                 │
                                                                 ▼
                                              M6 polish: platform gems gate,
                                              signed bundles, site/docs
```

M0–M2 (models + gem) and M3–M4 (Rust) are **parallel tracks**; they
join at M5.

### M0 — Resource Spec v1 freeze

- Deliverable: `schemas/registry.schema.json` merged in
  `models-fasttext-onnx` (plan 07). The registry shape is a cross-repo
  API — freeze it before both the gem client and kotoshu-rs parse it.
- Acceptance: schema merged; a sample registry validates; id scheme
  `kotoshu://models/{lang}/{tier}` locked.

### M1 — Gem: tier-aware ModelCache (PR to this repo)

- `Kotoshu.setup(:en, want: :model, tier: :fluency|:mini|:full)`;
  `ModelCache` resolves tier from the registry; fallback chain
  full→fluency→mini only when explicitly requested.
- Config: `model_tier` option (SCHEMA entry → env `KOTOSHU_MODEL_TIER`
  automatic), CLI `kotoshu setup LANG --model --tier mini`.
- Resolve stays cache-only; a missing tier raises
  `ResourceNotSetupError` exactly like today. No implicit downloads.
- Acceptance: specs for tier resolution + fallback; existing specs
  untouched (default tier = owner decision, see gates below).

### M2 — First models release (owner action required)

- Plan 07 workflow builds the release; **the tag name is the owner's
  decision** — the workflow refuses to invent versions. Default pin in
  the gem follows only after the owner picks.

### M3 — kotoshu-rs bootstrap (new repo `kotoshu/kotoshu-rs`, P0 of plan 66)

- Repo creation under the org (owner or delegated `gh repo create`).
- Scaffold per plan 66: workspace (lto fat / codegen-units 1),
  `kotoshu` core crate with `ffi/{mod,shared,c}.rs`, features
  `default=[] ruby wasm onnx parallel logging`, deny/typos/pre-commit,
  CI trio (`ci.yml`, `ruby-ffi.yml`, `wasm.yml`), release-plz config.
- **Conformance export first**: `rake kotoshu:conformance:export` in
  this repo writes golden JSONL (fixtures + suggestion outputs) to
  `conformance/`; kotoshu-rs CI consumes it — one source of truth,
  three enforcement points (C ABI, ruby feature, wasm).
- Acceptance: green CI incl. `--features ruby` under one MRI and a
  wasm32 build; C ABI round-trips the batch format on exported vectors.

### M4 — Port P1–P2: dictionary + suggest

- aff/dic parsing → affix expansion → lookup (P1); banded
  edit-distance, phonetic, keyboard, n-gram, composite ranking,
  frequency bonus (P2). Each lands with conformance green against the
  golden vectors — no "port now, verify later".
- Acceptance: full conformance pack passes on the C ABI; criterion
  benchmarks published in CI artifacts.

### M5 — Access libraries (the publish wave)

Order = blast-radius ascending, value descending:

1. **Ruby** — `ext/kotoshu_native` in this repo (thin magnus shim per
   plan 66), `KOTOSHU_BACKEND=native|ruby|auto`, `rake compat:ruby|
   native|compare` in CI. The gem keeps installing pure-Ruby with no
   toolchain. PR-gated like every change to this repo.
2. **JS/WASM** — `@kotoshu/wasm` built+published from kotoshu-rs
   (`wasm.yml`, wasm-pack); `kotoshu-js` re-exports it alongside the
   HTTP client. **npm publish needs the org's npm credentials —
   currently blocked** (same blocker as kotoshu-js itself).
3. **Python** — maturin wheel over the same core in `kotoshu-python`,
   optional extra alongside the HTTP client. **PyPI publish needs the
   org's token — currently blocked (403)**.
4. **Go** — stays on the HTTP path (kotoshu-server); cgo over the C
   ABI is a deliberate non-goal until demand appears.

- Acceptance per shim: conformance vectors pass through the binding;
  perf report vs pure-Ruby/HTTP path; version lines independent
  (parsanol policy).

### M6 — Polish

- Prebuilt platform gems via rake-compiler-dock **only if** adoption
  demands (gate, post-adoption — plan 66 policy).
- Signed offline bundles (plan 65 pillar: minisign/cosign over the
  registry + assets) — signature verification in gem and kotoshu-rs.
- Site: tier badges on language pages, `docs/caching` tier section,
  playground option to run `@kotoshu/wasm` locally once published.

## Owner-decision gates (never taken by tooling)

| Decision | Milestone |
|---|---|
| Registry/tier **default tier** (bandwidth vs accuracy) | M1 |
| Models **release tag & versions** | M2, every release |
| kotoshu-rs **crate versions, MSRV**, release-plz first release | M3+ |
| Ruby ext gem version; python/js package versions | M5 |
| License attribution wording (CC BY-SA inheritance) | M2 |
| gem required_ruby_version changes (if any) | never tooling's call |

## Publishing blockers that exist today

- PyPI token invalid/absent; npm org auth absent. The M5 publish wave
  for python/js cannot complete until the owner provides them — flag
  early, publish the code (repos, CI) regardless.

## Acceptance (whole train)

- `gem install kotoshu` → `kotoshu setup en` pulls the fluency tier by
  default (or the owner's chosen default), verified by sha256 from the
  registry, cache-only afterwards.
- `kotoshu-rs` passes the conformance pack on C ABI, `--features ruby`
  under MRI 3.2–4.0-head, and wasm32.
- `rake compat:compare` shows zero diffs between Ruby and native
  backends.
- `@kotoshu/wasm` loads in Node 18+ and browsers; python wheel
  installs without a Rust toolchain (or is clearly marked source-build).

## Status

_Planning._ Milestones promote to individual execution plans
(66 P0–P4 for M3–M4; per-shim plans for M5) as each opens.
