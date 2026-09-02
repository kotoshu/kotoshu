# 65 — Universal Kotoshu: master plan & roadmap

Polyglot engine · tiered micro-models · distribution everywhere.
This is the master plan for "full success": a spell-checking system
**every user can install in under two commands, on every platform,
for every language they write** — developers, writers, CI, enterprise,
and eventually office-suite users.

Supersedes the scale of `00-vision.md` (which remains the statement of
philosophy); this file is the execution roadmap that reaches it.

---

## 1. Grounding — what we know today

| Fact | Source | Implication |
|---|---|---|
| Microsoft Word ships **14 MB** of fluency models: one `word_fluency_v2.onnx` + a 168-byte runtime-config JSON, code-signed, on onnxruntime | `/Applications/Microsoft Word.app/Contents/Resources/WordModels.bundle` | Proof that a world-class fluency model is a **single-digit-MB ONNX artifact**. We already run onnxruntime. Same distribution pattern applies 1:1. |
| Our converted models are **~120 MB/lang** (`.onnx` + vocab JSON), 9 languages converted, sha256 manifest exists | `models-fasttext-onnx/manifest.json` | 10× too heavy for bundling. Needs vocab pruning + dim reduction + int8 quantization → tiers. |
| ~98 Hunspell dictionaries staged, each dir already has `license` + `package.json` | `dictionaries/` | License metadata foundation exists; must become machine-readable + redistribution-classified. |
| Gem already downloads → sha256-verifies → caches with TTL, cache-only hot path | `LanguageCache` / `FrequencyCache` / `ModelCache` | The resource *client* is done. What's missing is the resource *contract* (tiers, licenses, lockfiles) and the *small artifacts*. |
| 12 repos live: gem 0.6.0, lsp/server 0.1.0, go v0.1.0, action v1, 3 SDKs, docker, 3 content repos, site | RubyGems / Go proxy / GitHub | The surfaces exist. The gap is engine portability + model tiers + packaging depth. |

**North star.** *Any user, any platform, any language: install in ≤2
commands, work fully offline, and get tiered accuracy they can choose —
from a 1 MB dictionary to a 15 MB fluency model to a research-grade
full model.*

### Success metrics (measurable, per cut)

- **Languages**: 6 full-feature today → 30 wired at v1 → 98 at v2;
  mini+fluency tiers published for ≥30 languages.
- **Accuracy**: fluency tier within 2 % top-1 of the full tier on the
  benchmark harness; scores published per language × tier.
- **Size/time**: editor bundle < 25 MB; cold start < 5 s; CI cache hit
  = zero downloads; air-gapped install = one tarball + one command.
- **Portability**: conformance suite green on every engine
  implementation, on linux/amd64, linux/arm64, macOS universal,
  windows x64/arm64, and wasm32.

---

## 2. Five pillars

### Pillar 1 — Resource Spec v1 + registry (the contract)

One versioned format that every repo, cache, and SDK speaks:

```yaml
# kotoshu-resource-spec v1 (per language package)
language: en
version: 2026.09.1
license: { name: BSD-3-Clause, redistribution: allowed }   # or download-only
resources:
  spelling:   { path: spelling/index.dic, sha256: …, size: 551_762 }
  frequency:  { path: frequency/tiers.json, sha256: … }
  model:
    mini:     { path: models/mini.onnx,    sha256: …, size: ~2_000_000,
                metrics: { top1: 0.91, recall5: 0.98 } }
    fluency:  { path: models/fluency.onnx, sha256: …, size: ~14_000_000,
                metrics: { top1: 0.95, recall5: 0.99 } }
    full:     { path: models/full.onnx,    sha256: …, size: ~120_000_000 }
signature: cosign …
```

- **New repo `kotoshu/registry`**: one signed index aggregating
  dictionaries + frequency + models manifests; lockfile support
  (`kotoshu.lock`) for reproducible offline installs.
- License field is load-bearing: `redistribution: allowed` gates what
  may be **bundled** into images/extensions vs download-only.
- Gem change: `ResourceManager` resolves **tiers** (`want: [:spelling,
  model: :mini]`); `kotoshu export en --tiers mini --out en.tar.zst`
  and `kotoshu install ./en.tar.zst` close the air-gap loop.

### Pillar 2 — Tiered micro-models + model factory

| Tier | Size target | Contents | Purpose |
|---|---|---|---|
| **0 · dict** | 0.5–5 MB | Hunspell dic/aff + frequency tiers | Correctness; all 98 languages; no runtime |
| **1 · mini** | 1–3 MB | char-ngram-only embeddings, 32–64 d, int8 | OOV vectors + reranking where no model ships today |
| **2 · fluency** | 5–15 MB | pruned-vocab (top ~200 k) + dim-reduced + int8 embeddings, optional tiny context head | The Word-class tier: context-aware rerank, desert/dessert disambiguation |
| **3 · full** | 100–120 MB+ | today's `models-fasttext-onnx` artifacts | Research-grade; opt-in |

- **New repo `kotoshu/model-factory`**: pipeline `sources → prune →
  reduce → quantize → eval → sign → publish`. Sources: cc/wiki fastText
  vectors, Kelly + OPUS frequencies, dictionaries wordlists.
  Reuses `scripts/convert_fasttext_to_onnx.py` from
  models-fasttext-onnx as the `full` tier path.
- **Eval harness inside model-factory** (eval/): per-language benchmark
  suites seeded from the Spylls/Hunspell fixtures already ported in the
  gem, plus Wikipedia-typo corpora where available. Metrics: top-1,
  recall@5, MRR, latency, size. **Gate**: a tier only publishes with
  metrics attached; fluency must be within 2 % top-1 of full.
- Site gains an **accuracy page**: language × tier matrix with sizes
  and scores — honesty as a feature.
- `auto` tier selection: engine picks the best tier fitting a
  caller-supplied size budget (editor default 15 MB; server default full).

### Pillar 3 — Polyglot engine: one Rust core, feature-gated bindings (decision made)

Two meanings of "language" — both are goals:
- **Checked natural languages**: 98 staged (Pillar 1/2 supply them).
- **Implementation languages**: TS, Ruby, Python, Rust — decided; this is
  the **parsanol blueprint**, copied wholesale because it works in
  production at Ribose today (`parsanol-rs` + `parsanol-ruby`).

**Architecture (parsanol model):**

- **New repo `kotoshu/kotoshu-rs`** — Cargo workspace; core crate is a
  pure `rlib` (dic/aff parsing, affix expansion, trie/DAFSA lookup,
  suggestion strategies, rerank math, tokenization, resource verify).
  All FFI lives **inside the core** under `ffi/`, behind features:
  `ruby` (magnus), `wasm` (wasm-bindgen + js-sys + panic hook), and a
  **C ABI (`ffi/c.rs`) always available** — Python and any C-calling
  host bind through it. `ffi/shared.rs` defines the batch serialization
  every binding shares (parsanol's 3–5× FFI speedup pattern).
- **Language packages are thin cdylib shims in their own repos**:
  `kotoshu` gem gains `ext/kotoshu_native` (≈10 lines:
  `#[magnus::init]` calling `kotoshu::ffi::ruby::init`), depending on
  the core via git `features=["ruby"]`. Python adds a PyO3 shim wheel
  (maturin) over the same core; TS gets `@kotoshu/wasm` built from the
  core's `wasm` feature (Node *and* browser); Rust consumes the core
  directly. Each package versions independently (parsanol ships gem
  1.3.0 over core 0.5.1 — same policy).
- **Pure Ruby stays as the fallback and the semantic reference**: the
  gem works without the ext (`Kotoshu::Native.available?` guards), and
  the existing rspec suite runs against **both backends**
  (`rake compat:ruby` / `compat:native`, parsanol's compat-namespace
  pattern) — the gem's suite *is* the conformance suite.
- **ONNX: `ort` (pyke/ort v2), not the abandoned `onnxruntime` crate.**
  Policy: inference stays host-injected via an `EmbeddingProvider`
  trait; the core's own optional provider (`feature = "onnx"`) uses
  **`ort` with `load-dynamic`** so it dlopens the libonnxruntime the
  host already ships (Ruby's `onnxruntime` gem, pip's onnxruntime,
  onnxruntime-node) — one runtime per process, no double linking, tiny
  artifacts. Standalone Rust builds (CLI/LSP binaries) use ort's
  bundled binaries.
- **Distribution (parsanol's low-maintenance path)**: source gem that
  compiles on `gem install` via rb-sys (`create_rust_makefile`,
  stable-API fallback for ruby-head, optional auto toolchain install);
  prebuilt platform gems via rake-compiler-dock only if source builds
  hurt adoption. Core releases automated with release-plz.
- Copy list from parsanol, as policy: git-rev `[patch.crates-io]` for
  magnus/rb-sys when crates.io lags; `[net] git-fetch-with-cli`; wasm
  rustflags for getrandom; cargo-deny + typos + pre-commit; core
  profile `lto="fat", codegen-units=1`, ext profile `lto="off"`; core
  CI includes `ruby-ffi.yml` and `wasm.yml` so every binding is tested
  from the core repo.

### Pillar 4 — Distribution matrix (install in ≤2 commands, everywhere)

| Channel | Package | Phase |
|---|---|---|
| RubyGems | `kotoshu`, `-lsp`, `-server` | live |
| Go proxy | `kotoshu-go` | live |
| GitHub Action / Docker | `action-kotoshu`, CI image → GHCR | live → GHCR at 0.7 |
| PyPI / npm (SDKs) | `kotoshu`, `@kotoshu/client` | 0.7 (tokens pending) |
| npm `@kotoshu/wasm` + jsDelivr CDN | browser engine, plays into playground & embeds | 0.8 |
| VS Code Marketplace + Open VSX, JetBrains | editor extensions bundling fluency tiers (self-contained, <25 MB, no gem install) | 0.9–1.0 |
| Homebrew tap / winget / choco / scoop / apt via OBS | `kotoshu` CLI + standalone LSP binaries | 1.0–1.1 |
| OCI (GHCR) | server image + resource bundles as artifacts | 1.0 |
| Offline bundles | `kotoshu export/install` tarballs, cosign-signed, sbom (CycloneDX), SLSA provenance | 0.7 → 1.0 |

Standalone LSP at 0.9 via traveling-ruby/ruby-packer (single binary,
3 platforms) so editor users never need Ruby; native core later makes
this trivially static.

### Pillar 5 — Audiences & end-to-end journeys

| Audience | Need | Surface (→ phase) |
|---|---|---|
| Ruby devs | library API | gem (live) |
| Python/JS/Go devs | typed client | SDKs + server (live → 1.0 at 0.9) |
| Any-stack devs | no SDK needed | HTTP API + OpenAPI (live) |
| Editor writers | instant offline squiggles | LSP (live) → **bundled-fluency extension** (0.9–1.0) |
| CI maintainers | fail builds nicely | Action + Docker (live, mini-tier bake at 0.7) |
| Enterprise / air-gapped | offline, signed, auditable | export/install bundles + SBOM (0.7 → 1.0) |
| Multi-lingual writers | every language on demand | 30 wired (1.0) → 98 (2.0) |
| Office-suite users | proofing like Word | Word add-in / LibreOffice ext exploration (2.0 gate) |
| Low-resource language communities | contribute a language | dictionaries + model-factory recipes (1.0+) |

**Golden journeys** (each must be testable e2e): A) VS Code user
installs extension → squiggles offline in <25 MB. B) `gem install
kotoshu && kotoshu setup en` → check. C) CI run with cache hit → SARIF
annotations, zero downloads. D) air-gapped host: `kotoshu install
en.tar.zst` after `cosign verify`. E) browser playground running the
WASM engine on mini/fluency tiers. F) polyglot team: `docker run
kotoshu/server` + `pip install kotoshu`.

**Platform/arch matrix**: linux amd64/arm64, macOS universal2,
windows x64/arm64, wasm32-wasi (browser); CI builds all; native core
adds riscv64/mobile for free.

---

## 3. Repo-by-repo deltas

| Repo | Change |
|---|---|
| **new** `kotoshu/kotoshu-rs` | the Rust core workspace (see plan 66): pure-rlib engine, `ffi/{c,ruby,wasm}` feature-gated, conformance CI (`ruby-ffi.yml`, `wasm.yml`), release-plz, builds `@kotoshu/wasm` |
| `kotoshu` (gem) | gains `ext/kotoshu_native` cdylib shim + rb-sys extconf; pure-Ruby stays fallback; `rake compat:{ruby,native}` runs the suite on both backends; plus tier-aware ResourceManager, export/install bundles, lockfile, `auto` tier |
| `dictionaries` | machine-readable license manifest (name, redistribution flag) — already has per-lang files; aggregate to registry |
| `frequency-list-kelly` | no change; feed model-factory |
| `models-fasttext-onnx` | becomes the **full tier** source feeding model-factory; keep publishing |
| **new** `kotoshu/registry` | signed index, lockfiles, tier metadata, accuracy scores |
| **new** `kotoshu/model-factory` | prune/reduce/quantize/eval/sign/publish pipeline + benchmark suites |
| **new** `kotoshu/conformance` | shared golden-vector pack (extracted from the gem's Spylls fixtures); consumed by kotoshu-rs CI and any future implementation |
| `kotoshu-python` | adds native wheel (PyO3 shim over the core, maturin) alongside the HTTP client |
| `kotoshu-js` | adds `@kotoshu/wasm` re-export + types (built in kotoshu-rs); HTTP client stays |
| `kotoshu-server` | tier param on endpoints; resource listing; auth/metrics/Helm at GA |
| `kotoshu-lsp` | tier selection config; standalone single-binary distribution from the Rust core at 0.9 |
| `docker-kotoshu-ci` | publish to GHCR; bake mini tier (image stays <300 MB) |
| `action-kotoshu` | prewarm-mini default |
| `kotoshu.github.io` | accuracy page, downloads page, journey docs |

---

## 4. Roadmap (cuts)

| Cut | Theme | Key deliverables | Exit criteria |
|---|---|---|---|
| **0.7** | Resource Spec + mini tier + core scaffold | spec v1; `registry` repo; license manifest; model-factory alpha producing **mini** for 6 langs; gem tier-aware cache + export/install; GHCR image; SDK registry pushes; **`kotoshu-rs` workspace scaffolded with C ABI + conformance-vector pack v0** | mini tier installable for 6 langs; bundle verified offline; Docker <300 MB; core passes conformance v0 vectors |
| **0.8** | Fluency tier + core engine | **fluency** (≈14 MB) for 6 langs with eval gates; accuracy page; **kotoshu-rs ports dic/aff + lookup + suggest strategies, conformance green**; `@kotoshu/wasm` published from the core (resolves plan 63 — playground goes client-side) | fluency within 2 % top-1 of full; core matches Ruby backend on the whole suite; playground runs on wasm |
| **0.9** | Polyglot GA + editors | server 1.0 (auth/metrics/Helm); SDKs 1.0 with contract tests; **gem ships `ext/kotoshu_native` (both backends green); Python native wheel**; **VS Code extension** bundling fluency; **standalone single-binary LSP/CLI from the Rust core** (3 platforms) | dual-backend suite green; extension works offline <25 MB; single binary passes conformance |
| **1.0** | Kotoshu for developers | 30 languages wired; Neovim/JetBrains distributions; Action GA; cosign+SBOM on all artifacts; docs complete; Homebrew tap + winget | every journey A–F green; 5-signature quality bar met |
| **1.1–2.0** | Everyone | prebuilt platform gems (rake-compiler-dock) if source installs hurt; 98 languages; **gate:** office-suite add-ins exploration; mobile via wasm/native; auto-tier under size budgets | any user, any platform, any language, ≤2 commands |

**Decision gates** (explicit, not defaults): prebuilt-vs-source gems
(post-1.0, adoption-driven); office add-ins (2.0, only after a design
spike proves the API story). The native-core question is **decided**
(plan 66) — WASM and Ruby ext both come from the same `kotoshu-rs`.

---

## 5. Risks

| Risk | Mitigation |
|---|---|
| License heterogeneity blocks bundling | redistribution flag in spec; bundle only `allowed`; download-only path stays |
| Small models lose accuracy | eval gates with published metrics; tiers never silently replace full |
| Two engines (Ruby + Rust) drift | the gem's suite runs on **both backends** (`rake compat:*`); shared conformance-vector pack in kotoshu-rs CI; pure Ruby remains the reference |
| Source gem needs a Rust toolchain to install | rb-sys optional auto-install; pure-Ruby fallback always works; prebuilt platform gems gated at post-1.0 |
| magnus/rb-sys rev churn (Ruby 4.0 prep) | parsanol's patch policy copied: pin git revs in `[patch.crates-io]`, relax when crates.io catches up |
| ort dynamic-lib version skew with host onnxruntime | `load-dynamic` against onnxruntime 1.x C API (stable); document minimum; standalone Rust uses bundled ort |
| Registry uptime | GitHub Releases + CDN + lockfiles; caches already tolerate outage |
| Scope explosion | cuts with exit criteria; gates before big bets; 30-before-98 languages |

## Status

_Planning._ This document is the master index; per-cut plans get their
own `TODO.impl/{n}-*.md` when promoted, per house convention.
