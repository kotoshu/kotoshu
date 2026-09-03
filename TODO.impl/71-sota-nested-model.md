# 71 — Nested (2D-Matryoshka) Single-Artifact Experiment

Executes adopt-now item A4 of
[68-sota-adoption.md](68-sota-adoption.md) in `models-fasttext-onnx`.
Literature: plain prefix truncation of embeddings is safe at our
ratios ([arxiv 2605.16608](https://arxiv.org/html/2605.16608v2));
2D-MRL nesting along vocab+dims is validated practice
([arxiv 2410.13230](https://arxiv.org/html/2410.13230v1),
[HF Matryoshka guide](https://huggingface.co/blog/matryoshka)).

## Goal

One int8 file per language, frequency-ordered, whose **row-prefix
views ARE the tiers**: a `fasttext.{lang}.nested.onnx` (100k × 300d,
int8-per-row, ~30 MB) from which `fluency` = first-50k view (60k de)
and `mini` = first-10k view. If the views eval identically to the
shipped separate tiers, consumers download one artifact per language
instead of up to three, and tier "upgrades" are free (the bytes are
already on disk).

## Tasks

1. `scripts/build_nested.py` — build the nested artifact from the
   full model (same int8-per-row math as `build_tiers.py`; import, do
   not duplicate). Emit a truncation manifest (per-language prefix
   lengths) into the artifact's metadata_props and a sibling
   `fasttext.{lang}.nested.json`.
2. `eval/` view-eval: run the existing gate metrics for the fluency
   and mini views of the nested file against the shipped separate
   tier files — assert metric parity (same seeds, same probe
   sequences ⇒ identical numbers, since the construction is
   identical; any delta is a bug, not noise).
3. Size/bandwidth report: per language, {3 separate files} vs {full +
   nested}; which consumers win under which access pattern.
4. **Recommendation, not adoption**: registry ids and the release
   workflow stay unchanged in this plan. Adoption = a follow-up
   registry v2 field (`view_of`) + gem/kotoshu-rs resolver support,
   proposed only if the parity + size report supports it.

## Acceptance

- Nested views eval **identically** (bit-level metric parity) to the
  shipped tiers for all 9 languages.
- Size report committed (`eval/reports/nested.{lang}.json` summary).
- No change to registry.json, manifest.json, or release.yml in this
  plan.

## Dependencies

- After 69 if report regeneration is in flight (same eval files) —
  sequence to avoid collisions; otherwise independent.
- Owner gate: adoption itself (new registry field + default artifact
  strategy) is an owner decision.

## Status

**Experiment complete (2026-09-03, models PR #6 merged).** build_
nested.py + check_nested_parity.py; 18/18 EXACT array + metric parity
against the keyboard-aware reports. Recommendation recorded in
nested.summary.json: separate tiers stay the default (mini-only users
would pay ~10x); nested ships as an optional all-in-one if adopted.
Adoption (registry view_of field + resolver support) remains an owner
decision - deliberately not taken.
