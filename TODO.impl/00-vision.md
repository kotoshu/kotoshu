# Kotoshu Vision & Master Plan

> **Execution roadmap**: [65-universal-kotoshu.md](65-universal-kotoshu.md)
> is the master plan to "full success" — one Rust core with TS/Ruby/
> Python/Rust interfaces ([66-kotoshu-core.md](66-kotoshu-core.md),
> the parsanol blueprint: feature-gated FFI in the core, thin cdylib
> shims per language, `ort` for ONNX), tiered micro-models (mini ≈2 MB
> / fluency ≈14 MB / full ≈120 MB, benchmarked and labeled), and
> distribution on every channel (registries, editor marketplaces, OS
> packages, containers, signed offline bundles). Grounded in Microsoft
> Word's proof that a 14 MB signed ONNX fluency model is world-class.
> This file remains the philosophy; 65 is the road.

## What Kotoshu is becoming

**A pure-Ruby spellchecker that works for every language by dynamically
downloading the right dictionary + frequency data + embedding model on
demand.**

Three load-bearing promises:

1. **Pure Ruby workflow.** No shelling out to `hunspell`, `aspell`, or any
   external binary. The only native dependency is `onnxruntime` (for embedding
   inference). Every other piece — affix parsing, compounding, suggestion
   algorithms, language detection, document parsing, interactive UI, output
   formatting — is Ruby that ships in the gem.
2. **Dynamic resource resolution.** Given any text, Kotoshu detects the
   language, resolves the dictionary + frequency list + embedding model +
   grammar rules that language needs, downloads them on first use into
   `~/.kotoshu/`, verifies their integrity, and caches with TTL. The user
   never installs dictionaries manually.
3. **All languages.** Latin scripts (Hunspell morphological rules), CJK
   (morphological tokenizers + confusion rules — no traditional spellcheck),
   RTL (shaping-aware affix rules). A pluggable per-language module system
   decides what each language uses.

## Three analysis dimensions, composed per language

| Dimension | Source | Role |
|---|---|---|
| Traditional | Hunspell `.aff`/`.dic` | Authoritative correctness, morphological generation |
| Semantic | FastText ONNX embeddings | Context-aware reranking, OOV handling |
| Grammar | `rules.yaml` per language | Style/usage rules LanguageTool-style |

Each language module declares which dimensions it supports; the pipeline
composes whatever is available.

## The five repos and what they're for

| Repo | Role |
|---|---|
| `kotoshu/kotoshu` | The gem (this one). Ruby API + CLI + analysis pipeline |
| `kotoshu/dictionaries` | Hunspell dictionaries, 98 language dirs |
| `kotoshu/frequency-list-kelly` | Kelly Project frequency tiers for ranking |
| `kotoshu/models-fasttext-onnx` | FastText embeddings converted to ONNX |
| `kotoshu/kotoshu.github.io` | Marketing/docs site |

The gem depends on the other four as **content repos** — never vendored, always
fetched on demand by the cache layer.

## Plan index for this repo

| # | Plan | Why |
|---|---|---|
| 01 | [Hunspell correctness](01-hunspell-correctness.md) | Core lookup is ~50% on Spylls fixtures — must be fixed before anything trusts it |
| 02 | [CLI unification](02-cli-unification.md) | Two competing `check` commands; only the basic one is wired |
| 03 | [Dynamic resource download](03-dynamic-download.md) | The promise — unified resolver for any language |
| 04 | [Language modules](04-language-modules.md) | Wire 93+ dictionaries into the language module system |
| 05 | [Semantic path productionization](05-semantic-path.md) | Make ONNX reranking always-available, memory-bounded |
| 06 | [CJK support](06-cjk-support.md) | Japanese + Chinese (different paradigm — tokenizers + confusion) |
| 07 | [RTL support](07-rtl-support.md) | Arabic, Hebrew, Persian, Urdu |
| 08 | [Grammar engine](08-grammar-engine.md) | LanguageTool-style rule loader and pattern matchers |
| 09 | [Integrity & security](09-integrity-security.md) | Checksums, signed releases, audit log for downloads |
| 10 | [Testing & CI](10-testing-ci.md) | Coverage targets, CI matrix, perf benchmarks |
| 11 | [Release v1.0](11-release-v1.md) | Tag, publish, CHANGELOG, supported-language matrix |

## Cross-repo dependency order

```
09-integrity ─┐
03-download ──┼─► 04-language-modules ─► 06-cjk ─┐
              │                                  ├─► 08-grammar ─► 11-release
              ├─► 01-hunspell ──────────────────┤
              └─► 05-semantic ───────────────────┘

02-cli, 07-rtl, 10-testing can run in parallel with the above
```

| Plan 03 (dynamic download) is the unlock — it depends on 09 (integrity) and
unblocks both 04 (language modules) and the user-facing "any language"
promise. Plans 01 (Hunspell) and 05 (semantic) can proceed independently.

Plans 60–64 are the **ecosystem / reach** track — they turn the working
gem into something users actually adopt. They live in their own repos
under `kotoshu/` per the five-repo workspace model:

| # | Plan | Why |
|---|---|---|
| 60 | [LSP server](60-lsp-server.md) | One server, every editor. Highest-leverage reach. |
| 61 | [Editor & CI ecosystem](61-editor-ecosystem.md) | VS Code, Vim, JetBrains, GitHub Action, pre-commit hooks |
| 62 | [Framework integrations](62-framework-integrations.md) | Rails validators, Jekyll rake tasks, RSpec matchers — inside the library gem |
| 63 | [Web playground (WASM)](63-web-playground-wasm.md) | Browser playground at `kotoshu.github.io/playground/` |
| 64 | [HTTP API & SDKs](64-http-api-and-sdks.md) | Self-hostable server + Python / JS / Go SDKs for non-Ruby stacks |

Plan 67 is the **delivery train** that publishes 65/66: tiered models
(mini/fluency/full) through the models repo's registry + releases, the
kotoshu-rs bootstrap and port, and the Ruby / WASM / Python access
libraries — [67-kotoshu-rs-and-access-libraries.md](67-kotoshu-rs-and-access-libraries.md).

Plan 68 is the **research adoption plan** (2026-09-02 SOTA survey):
what modern GEC/embedding/quantization research and frontier-model
training techniques Kotoshu adopts, adapts, or rejects —
[68-sota-adoption.md](68-sota-adoption.md). Its adopt-now items are
executed by plans
[69 (keyboard typo eval + corpus benchmark)](69-sota-typo-eval.md),
[70 (confidence cascade)](70-sota-confidence-cascade.md), and
[71 (nested single-artifact experiment)](71-sota-nested-model.md).
The remaining SOTA items are planned as
[72 (Model2Vec evaluation)](72-model2vec-evaluation.md),
[73 (RL-trained reranker, gated)](73-rl-reranker.md),
[74 (distilled reranker, gated)](74-distilled-reranker.md),
[75 (LLM-as-evaluator)](75-llm-evaluator.md), and
[76 (optional external LLM backend, gated on demand)](76-optional-llm-backend.md).

Plans 77–82 are the **adoption wave** (owner ask 2026-09-05: are the
models comprehensive, how do we cover more places, docs + news):
closing the verified user gaps after all channels went live.

| # | Plan | Gap it closes |
|---|---|---|
| 77 | [Model coverage expansion](77-model-coverage-expansion.md) | Semantic models cover 9 languages vs 98 dictionaries — expand to 25+ |
| 78 | [In-browser playground](78-in-browser-playground.md) | /playground needs a running server; @kotoshu/wasm enables zero-install |
| 79 | [News + releases](79-news-and-releases.md) | No news surface on the site; seven registries shipped invisibly |
| 80 | [Ecosystem docs](80-ecosystem-docs.md) | Docs are gem-only; pip/npm/cargo/go/HTTP/LSP/Action users have no path in |
| 81 | [Editor reach](81-editor-reach.md) | kotoshu-lsp shipped but no VS Code package; no pre-commit hook (supersedes 61 remainder) |
| 82 | [Document ignores + baselines](82-doc-formats-and-ignores.md) | No inline suppressions; no CI baseline freeze |

Plans 83–89 are **wave 2** (2026-09-05, owner re-ask after the wave-1
ship): driving models toward full intersection coverage, making the
22 model languages full-feature, semantic reranking in the browser,
and the site/docs truth that follows.

| # | Plan | Gap it closes |
|---|---|---|
| 83 | [Models batch 2](83-models-batch-2.md) | ar/fa/he have modules but no models; ~50 more intersection languages; fi/id dictionary sourcing |
| 84 | [Language modules + keyboards wave 2](84-language-modules-wave2.md) | 13 model languages lack gem modules; 11 keyboard layouts missing |
| 85 | [Wasm model API](85-wasm-model-api.md) | Browser semantic reranking — no model API on the wasm surface, CORS distribution gap |
| 86 | [Site truth wave 2](86-site-truth-wave2.md) | Ignores/baselines undocumented; no Windows page; wrong personal.dic path in CLI docs; playground breadth |
| 87 | [LSP personal dictionary](87-lsp-personal-dictionary.md) | Server never reads personal.dic — add-to-dictionary appears broken |
| 88 | [CLI directory mode](88-cli-directory-mode.md) | No tree checking — the actual CI workflow |
| 89 | [Framework integrations](89-framework-integrations-exec.md) | Executes plan 62: Rails validator, RSpec matcher, Rake/Jekyll tasks |

Plans 91–95 are **wave 3** (2026-09-05 late): the correctness core the
site flip exposed, the browser-models distribution fix, Python wheels,
the docs for wave-2 features, and editor/action truth.

| # | Plan | Gap it closes |
|---|---|---|
| 91 | [Unicode + sv aff](91-unicode-and-sv-aff.md) | Executes plan 90: ASCII-only word detection hides non-Latin scripts; AffReader crashes on Swedish |
| 92 | [Tier mirror CORS](92-tier-mirror-cors.md) | Media host already sends ACAO — mirror the tiers, finish the browser-models path |
| 93 | [Python wheels](93-python-wheels.md) | kotoshu-native is macOS-only on PyPI; build the platform matrix + keyless publish |
| 94 | [Site integrations docs](94-site-integrations-docs.md) | Rails/RSpec/Rake/Jekyll + directory mode shipped undocumented; action page stale |
| 95 | [Editor + action polish](95-editor-action-polish.md) | Extension delegates the now-existing server command; action gains baseline + 19 languages |

Plans 96–97 are **wave 4** (2026-09-06): the audit found the wave-1–3
surface complete except two honest items — the HTTP server never
loads models, and plan 59's YARD reference is still unpublished. (The
Rust engine was audited too: its AST-based aff parser is immune to
the Swedish COMPOUNDRULE bug by design.)

| # | Plan | Gap it closes |
|---|---|---|
| 96 | [Server semantic models](96-server-semantic-models.md) | /v1/check is dictionary-only — SDK users get no reranking through HTTP |
| 97 | [YARD execution](97-yard-execution.md) | Executes plan 59: the Ruby API reference still does not exist |

Plan 98 is **wave 5, the cleanup and closeout** (2026-09-06): after the
release-day cuts (gem 0.8.0 → 0.9.0, @kotoshu/wasm 0.2.0, registry
v1.3.0 with nb, lsp/server 0.1.1 via trusted publishing) the workspace
was swept — 214 GB of models worktrees reclaimed, the plan corpus
01–98 fully tracked, verification evidence preserved.

| # | Plan | What it records |
|---|---|---|
| 98 | [Campaign cleanup](98-campaign-cleanup.md) | The inventory, the executed sweep, the keep list, and the deliberately-unforced items |

Campaign state at close: every channel live and populated; the
convertible model pool exhausted at 55 languages; owner-side
remnants (PyPI registrations, marketplace PAT, nds/fi calls) recorded
in the plans, not pending work.

Plans 99-104 are **wave 6, the live-quality follow-through**
(2026-09-07), written after the sweep-performance arc (gem 0.9.1 ->
0.9.2, @kotoshu/wasm 0.3.0 -> 0.3.2) and a fresh state audit: 55 model
languages x 3 tiers confirmed (ja/ko/zh rerank-only by design), no LID
resource mirrored, lsp/server `~> 0.6` constraints already resolving
current engines, site docs carrying stale version references.

| # | Plan | Gap it closes |
|---|---|---|
| 99 | [Site truth + performance docs](99-site-truth-performance-docs.md) | Docs misstate current versions; the measured per-language latency is unpublished |
| 100 | [Full-feature batch 3](100-full-feature-batch3.md) | ~35 languages have dictionaries + models but no gem module - the big-audience remainder (ar id fa he ...) |
| 101 | [int4 tier experiment](101-int4-tier-experiment.md) | Halving tier bytes was named (B1) but never run through the gates |
| 102 | [LID chain](102-lid-chain.md) | No detection in the registry, wasm, or playground - users pick the language blind |
| 103 | [OOV bucket tables](103-oov-bucket-tables.md) | Model candidates miss n-grams absent from vocab (the Teh gap's model half) |
| 104 | [VS Code marketplace readiness](104-vscode-marketplace-readiness.md) | The extension is built but not installable; everything short of the owner PAT |

Execution notes: plan 103 is sequenced after 101 (same repo, one
worktree at a time); all site-facing flips (99, 100, 102's playground
half, 104's link line) land through one coordinated site pass to keep
the repo conflict-free; lsp/server 0.1.2 bumps are deliberately NOT
planned - the `~> 0.6` floor already resolves 0.9.2 for fresh installs.

Dependency order across the ecosystem track:

```
60-lsp ─┬─► 61-editor-ecosystem
        ├─► 62-framework-integrations (also depends on 02)
        └─► 64-http-api (also depends on 02, 03, 05, 09)
63-web-playground is independent (depends only on 02, 04)
```

## Cross-repo plan files

Each content repo has its own `TODO.impl/` directory:

- `dictionaries/TODO.impl/` — manifest, coverage matrix, releases, metadata, licenses
- `frequency-list-kelly/TODO.impl/` — coverage extension, validation, releases
- `models-fasttext-onnx/TODO.impl/` — publishing, storage, manifest, conversion CI
- `kotoshu.github.io/TODO.impl/` — site skeleton, content, examples landing

## Source-of-truth note

Older planning docs now live in `docs/`
(`KOTOSHU_FULL_PLAN.md`, `KOTOSHU_SOLIDIFICATION_PLAN.md`,
`KOTOSHU_LANGUAGETOOL_GAPS.md`, `ARCHITECTURE_IMPROVEMENTS.md`,
`ARCHITECTURE_IMPROVEMENTS_PLAN.md`, `TDD_ITERATION_STRATEGY.md`,
`ONNX_FUNCTIONAL_VERIFICATION.md`). Actionable items have been
integrated into the relevant execution plans below — pointers in each
plan name the source.

| Source | Integrated into |
|---|---|
| `docs/KOTOSHU_FULL_PLAN.md` | Phases 0–8 spread across `01`–`11` per phase scope |
| `docs/KOTOSHU_SOLIDIFICATION_PLAN.md` (49 OOP items) | `01` (Parts 1–2 Hunspell/CSpell), `04`/`06`/`07` (Part 3 LanguageTool), `10` (Part 5 testing); Part 4 perf items live in the relevant feature plan |
| `docs/KOTOSHU_LANGUAGETOOL_GAPS.md` | `08` (rules, confusion), `02` (CLI surface, output formats), `04` (target languages) |
| `docs/ARCHITECTURE_IMPROVEMENTS.md` (15 patterns) | Most patterns are architectural guidance applied across plans; load-bearing rules captured in `CLAUDE.md` |
| `docs/ARCHITECTURE_IMPROVEMENTS_PLAN.md` (5 phases) | Phase 1 perf items in `01`/`05`; Phase 2 architecture in `00-vision` (this doc); Phase 3 UX mostly implemented (`PersonalDictionary`, `ProjectConfig`, `FluentChecker` exist); Phase 4 quality in `10`; Phase 5 polish spread |
| `docs/TDD_ITERATION_STRATEGY.md` | `10` (test methodology + CI); project-rule overrides (no doubles, behavior-not-implementation) in `CLAUDE.md` |
| `docs/ONNX_FUNCTIONAL_VERIFICATION.md` | `05` (semantic path productionization) |


Plans 105-107 plus models 09 and site 11 are **wave 7, detection and
coverage depth** (2026-09-07): after the wave-6 releases (gem 0.9.3,
wasm 0.4.0, registry v1.4.0, action v2), the remaining gaps are the
personal dictionary never reaching the check path, detection stuck on
a 7-language heuristic, buckets only for en/de, and the playground not
yet passing bucket bytes to loadModel.

| # | Plan | Gap it closes |
|---|---|---|
| 105 | [Personal dictionary in check](105-personal-dictionary-in-check.md) | kotoshu personal add then check still flags the word |
| 106 | [Native LID detection](106-native-lid-detection.md) | detect is a 7-language heuristic; the pure-Rust lid reader exists unused |
| 107 | models [09 bucket expansion](../../models-fasttext-onnx/TODO.impl/09-bucket-table-expansion.md) | bucket OOV siblings exist only for en and de |
| — | site 11 playground buckets | wasm 0.4.0 accepts bucketsBytes; the worker never fetches the sibling |


Plans 107-109 are **wave 8, reachability and the road to 1.0**
(2026-09-07): after wave 7 (personal dict in check, 176-language
detection, buckets rolling to all languages), the remaining user gaps
are the sixty-plus staged dictionaries unreachable without a module,
the last big-population languages (ko, ne), and the absence of a
stability commitment adopters can build on.

| # | Plan | Gap it closes |
|---|---|---|
| 107 | [Basic support for every staged language](107-basic-support-every-staged-language.md) | setup rejects 60+ staged languages; modules become upgrades, not gates |
| 108 | [ko and ne full-feature](108-ko-ne-full-feature.md) | Hangul and Devanagari - the last ~100M speakers without support |
| 109 | [The 1.0 readiness audit](109-ten-audit.md) | no frozen surface or stability policy for adopters |

Sequencing: 108 after 107 (same area); 109 is analysis-only and runs in
parallel. The 1.0 cut itself remains the owner's version call.
