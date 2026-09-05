# 77 — Model coverage expansion: 9 → 25+ languages

> Asked by the owner 2026-09-05: "Are our models fully complete and
> comprehensive with no user gaps?" They are not — this plan closes the gap.

## Context

The registry (models-fasttext-onnx `registry.json`, v1.0.1) carries
semantic models for exactly **9 languages** (de en es fr ja ko pt ru zh)
× 3 tiers = 27 entries. Meanwhile:

- `dictionaries/` repo: **98** languages with Hunspell `.aff`/`.dic`
- FastText CC vectors exist for **157+** languages
- The site language matrix and gem language registry advertise the
  dictionary breadth, but semantic reranking silently stops at 9

A user who spells in Italian, Polish, Turkish, or Dutch gets the
traditional path only. That is the largest user gap in the ecosystem.

## What is NOT changing

- The tier recipe (full 300d / fluency int8 top-50k / mini int8
  top-10k) — settled by plan 67's measured gates; no SVD, no Model2Vec.
- The eval gates from plan 67's gate table: fluency
  `rank_corr ≥ 0.97 / top1 ≥ 0.95`, mini `rank_corr ≥ 0.90 /
  top1 ≥ 0.85` (keyboard-aware eval from plan 69). A language that
  fails gates ships **no** tiers rather than bad tiers.

## Phases

### Phase 1 — candidate selection (deterministic)

Candidates = dictionaries repo dirs ∩ FastText `cc.{lang}.300.vec`
availability ∩ eval-gate pass. Rank by speaker base × dictionary
quality (dictionary repo manifest). Batch 1 target (16):

```
it nl pl uk tr cs sv el hu ro da fi no id vi ca
```

Batch 2 (stretch, if compute allows): ar fa he th vi-tok hi bn ms tl
sk sl lt lv et is hr sr bg.

### Phase 2 — pipeline run per language

Use the existing scripts (see models repo `TODO.impl/01`, `04`, `06`):
download `cc.{lang}.300.vec.gz` → convert to ONNX full → int8 +
vocab-cut to fluency/mini → keyboard-aware eval → gates. Record
per-language eval JSON into `eval/` like the existing nine.

### Phase 3 — registry + release

Regenerate `registry.json` (+ manifest, schemas untouched), bump
registry_version, tag `v1.1.0` (policy from models plan 05: pre-declared
minor for coverage expansion). Release assets: 3 tiers × new languages,
mirrored to the media host per plan 07's distribution map.

### Phase 4 — downstream truth updates

- Gem `Language` registry: full-feature languages list gains the
  new entries (spelling + model available).
- Site language matrix + per-language pages: flip `hasModel` for
  the new set; copy updated by the site plan (79/80 reuse).
- kotoshu-rs / SDKs: no code change (registry-driven).

## Owner gates

- None for batch 1 execution (standing directive 2026-09-05).
- Version numbers: v1.1.0 follows plan 05's pre-declared policy —
  registry major/minor tracks coverage, patch tracks regeneration.
  If the owner objects, yank per policy is NOT possible for release
  assets — ask first if in doubt.

## Success criteria

- ≥ 8 new languages pass gates and appear in registry + release.
- Every shipped tier has eval JSON proving the gates.
- Registry schema version unchanged; gem + site consume it without
  code changes.

## Status

**Implemented (2026-09-05, models PR #13 + tag v1.1.0).** 13 of 16
batch-one candidates shipped: ca cs da el hu it nl pl ro sv tr uk vi
— 22 languages x 3 tiers, 66 registry resources, 134 release assets.
All tiers passed the gates unweakened (fluency rank_corr 0.9999,
top1 0.9583-1.0000). noise.py grew QWERTY/QWERTZ supplements plus
curated Turkish-Q / Ukrainian JCUKEN / Greek-phonetic grids; a
pre-existing release_notes.py crash on null tier mirrors was fixed
in passing. Released registry byte-identical to committed (local
rebuild reproduces CI sha256).

Dropped from batch 1 (no dictionaries-repo aff/dic): fi, no, id —
`no` exists only as nb/nn; an owner mapping decision for a v1.2.
Site truth updated (MODEL_LANGUAGES + news entry, site PR #4); the
gem needed no change (registry-driven).
