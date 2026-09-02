# 66 — kotoshu-rs: the Rust core (parsanol blueprint)

Implements Pillar 3 of [65-universal-kotoshu.md](65-universal-kotoshu.md).
**The approach is copied wholesale from `parsanol-rs` + `parsanol-ruby`**
(Ribose, in production) because it demonstrably works: one pure-Rust
core, all FFI feature-gated *inside* the core, per-language packages as
thin cdylib shims, pure-Ruby fallback retained, dual-backend test suite.

## Decision: `ort`, not `onnxruntime`

- **`ort`** (pykeio/ort, v2.x): actively maintained, tracks current
  onnxruntime, execution providers, and — decisive for us — a
  **`load-dynamic`** mode that dlopens a host-provided
  libonnxruntime instead of linking one in.
- The `onnxruntime` crate (nbigaouette) is effectively unmaintained and
  pinned to old runtime versions. Rejected.
- **Policy**: inference is host-injected via an `EmbeddingProvider`
  trait (rerank math in the core works on vectors the host supplies).
  The core's own provider is `feature = "onnx"` →
  `ort = { version = "2", default-features = false, features =
  ["load-dynamic"] }`, so Ruby/Python/Node hosts share the lib they
  already ship (the `onnxruntime` gem / pip / onnxruntime-node).
  Standalone Rust builds (CLI, LSP binary) enable ort's bundled
  binaries instead. Minimum onnxruntime 1.x documented per release.

### Addendum (2026-09-02): runtime validation + `onnx-ir` assessment

- **ort under real load** — Weirich, "Rust, ORT, ONNX: Real-Time YOLO on
  a Live Webcam" (Nov 2025): YOLOv11 at 30 FPS webcam inference in Rust
  via a four-thread pipeline (capture → resize/pack → inference →
  render), ~22% CPU on a MacBook; same expected on a Jetson with
  hardware acceleration. Our workload (single-token embedding lookups,
  rerank of ≤25 candidates) is orders of magnitude lighter — ort
  headroom is not a risk. The article's pipeline shape is also the
  reference pattern for the LSP/server: inference isolated on its own
  worker thread, results serialized back; the editor loop never blocks
  on a model call. ORT's WebAssembly support is confirmed for the
  browser path.
- **`onnx-ir`** (tracel-ai, Burn ecosystem) is a pure-Rust ONNX
  **parser → IR**, not a runtime: executing the graph means burn-import
  compiling it to a Burn backend — and therefore **zero native
  dependencies**. That matters exactly where `load-dynamic` cannot
  work: static musl CLI binaries and wasm32. FastText-style graphs
  (embedding gather + matmul + normalization) sit comfortably inside
  Burn's operator coverage.
- **Policy consequence — the trait already anticipated this.** `ort`
  stays THE provider (decided above). At P3, if ort's wasm story proves
  heavy, evaluate a `burn` provider (`onnx-ir`/burn-import) behind the
  same `EmbeddingProvider` trait, gated to `wasm32`/static targets
  only. `tract` (sonos — pure-Rust inference, no C deps) is the noted
  third option if Burn's op coverage ever falls short. One trait,
  three candidate providers, no core changes.

## Workspace layout (mirrors parsanol-rs)

```
kotoshu-rs/
├── Cargo.toml                  # workspace: lto="fat", codegen-units=1
├── deny.toml  typos.toml  release-plz.toml  .pre-commit-config.yaml
├── .cargo/config.toml          # [net] git-fetch-with-cli; wasm32 getrandom flags
├── kotoshu/                    # core crate, crate-type = ["rlib"]
│   └── src/
│       ├── lib.rs              # pub mod ffi; pub use ffi::ruby as ruby_ffi
│       ├── portable/           # portability layer (parsanol pattern)
│       ├── dict/               # aff/dic parsing, affix expansion, DAFSA/trie
│       ├── suggest/            # edit-distance(banded), phonetic, keyboard, ngram
│       ├── rerank.rs           # pure vector math + EmbeddingProvider trait
│       ├── resource/           # manifest parse, sha256, tier metadata
│       ├── tokenize.rs
│       └── ffi/
│           ├── mod.rs          # feature gates + re-exports
│           ├── shared.rs       # batch serialization shared by ALL bindings
│           ├── c.rs            # C ABI — always available (parsanol: c/ always)
│           ├── ruby/           # feature = "ruby"  → magnus
│           └── wasm/           # feature = "wasm"  → wasm-bindgen, js-sys,
│                               #   console_error_panic_hook
├── benches/  examples/  tests/ # criterion, proptest, conformance-vector runner
└── .github/workflows/
    ├── _rust-setup.yml  _rust-build-test.yml  ci.yml
    ├── release.yml              # release-plz → crates.io
    ├── release-binary.yml       # kotoshu CLI / kotoshu-lsp single binaries
    ├── ruby-ffi.yml             # builds core with feature "ruby", runs magnus tests
    ├── wasm.yml                 # wasm-pack build → publishes @kotoshu/wasm
    └── docs.yml
```

**Features**: `default = []`, `ruby = ["magnus"]`,
`wasm = ["wasm-bindgen", "js-sys", "console_error_panic_hook"]`,
`onnx = ["ort/load-dynamic"]`, `parallel = ["rayon"]`, `logging = ["log"]`.
Core profile `opt-level 3, lto true, codegen-units 1`; dep crates
`opt-level "s"` — parsanol's exact settings.

## Language packages (mirrors parsanol-ruby)

| Package | Shim | Notes |
|---|---|---|
| `kotoshu` gem | `ext/kotoshu_native` cdylib: `#[magnus::init] fn init(r) { kotoshu::ffi::ruby::init(r) }` | gemspec: `spec.extensions`, runtime dep `rb_sys "~> 0.9"`, files include `Cargo.toml`+`Cargo.lock`, reject `*.so|dylib|bundle|dll`; versions independently of the core (parsanol: gem 1.3.x over core 0.5.x) |
| `kotoshu-python` | PyO3 shim crate in-repo, maturin wheels | over the same core; HTTP client remains the pure-Python path |
| `kotoshu-js` | none — re-exports `@kotoshu/wasm` | wasm package built+published from kotoshu-rs (`wasm.yml`); napi-rs native later only if wasm latency hurts |
| Rust CLI/LSP | direct dep | `release-binary.yml` ships static binaries (linux amd64/arm64, macOS universal, windows x64/arm64) |

**extconf.rb (copied verbatim in spirit)**: `require "rb_sys/mkmf"`;
`create_rust_makefile("kotoshu/kotoshu_native")` with
`r.profile = ENV.fetch("RB_SYS_CARGO_PROFILE", :dev).to_sym`,
`r.use_stable_api_compiled_fallback = true`,
`r.force_install_rust_toolchain = false`. Source gem compiles on
install — **no cross-compile matrix to maintain**; prebuilt platform
gems (rake-compiler-dock) only if adoption demands (gate, post-1.0).

**Ruby loader/fallback**: `Kotoshu::Native.available?` guard; every
public API keeps its pure-Ruby path; the ext is a pure accelerator —
identical results, faster. Env `KOTOSHU_BACKEND=native|ruby|auto`
selects explicitly for debugging/benching.

**Dual-backend conformance**: parsanol's `compat:` namespace, applied to
the suite we already own —
`rake compat:ruby` / `compat:native` / `compat:compare` run the gem's
full rspec suite (Splylls/Hunspell fixtures included) against each
backend and diff the outputs. CI runs both. Golden vectors from the
same fixtures are exported into `kotoshu/conformance` and consumed by
kotoshu-rs CI so the C ABI, wasm build, and future ports are held to
identical outputs — **one source of truth, three enforcement points.**

## Porting order (each step lands with conformance green)

1. **P0 scaffold**: workspace, `ffi/shared.rs` batch format, C ABI
   skeleton, conformance-vector runner, CI (incl. `ruby-ffi.yml`,
   `wasm.yml`), release-plz wired.
2. **P1 dictionary**: aff parser → dic loader → affix expansion →
   lookup (`correct?`). Vectors: the gem's affix/lookup specs.
3. **P2 suggest**: banded edit-distance with threshold (port the gem's
   optimized DP), phonetic, keyboard proximity, n-gram, composite
   ranking, frequency bonus. Vectors: suggestion specs (ranked lists).
4. **P3 rerank + resources**: `EmbeddingProvider` trait + ort provider
   (load-dynamic); manifest/sha256/tier parse. Vectors: rerank specs.
5. **P4 shims**: gem ext (0.9), Python wheel, wasm publish, single-binary
   LSP/CLI.

## Parsanol details adopted as policy

- `[patch.crates-io]` git-revs for magnus/magnus-macros/rb-sys when
  crates.io lags Ruby (current parsanol revs noted; relax on release).
- `ffi/shared.rs` batch FFI format — one serialization, all bindings;
  parsanol measured 3–5× over object-by-object FFI.
- Quality kit: cargo-deny (`deny.toml`), typos, pre-commit, criterion
  benches, proptest, `rust-version` floor per crate.
- Core repo tests the Ruby feature itself (`ruby-ffi.yml`) so binding
  breakage is caught in the core's CI, not downstream.
- Separate version lines per package; release-plz automates the core's.

## Acceptance

- `kotoshu-rs` passes the full conformance-vector pack on the C ABI,
  with `--features ruby` under MRI 3.2/3.3/3.4/4.0-head, and as wasm32.
- `rake compat:compare` in the gem shows zero diffs between backends.
- `gem install kotoshu` works WITHOUT a Rust toolchain (pure Ruby) and
  WITH one (native build), same results either way.
- `@kotoshu/wasm` loads in Node 18+ and browsers; playground runs on it.

## Risks

Two engines during port (mitigated: dual-backend suite gates every
merge); Rust toolchain requirement for the native path (mitigated:
fallback + prebuilt gate); magnus/rb-sys rev churn (patch policy);
ort dynamic-lib skew (documented minimum, C API stable across 1.x).

## Status

_Planning._ Promotes into P0–P4 execution plans when cut 0.7 opens.
