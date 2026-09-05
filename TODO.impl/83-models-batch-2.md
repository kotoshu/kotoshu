# 83 — Models batch 2: every dictionary language FastText can serve

> Wave-2 continuation of [77](77-model-coverage-expansion.md).
> v1.1.0 shipped 22 languages; the user asks again: are the models
> comprehensive? Not yet — this plan drives toward full intersection
> coverage.

## Context

- Dictionaries repo: 98 languages. Models registry v1.1.0: 22.
- FastText CC vectors exist for 157+ languages.
- The intersection (dictionaries ∩ fastText, minus the 22 shipped) is
  the candidate pool — enumerate it exactly; expect ~50-60.
- Notable misses with gem language modules already wired: **ar, fa,
  he** (RTL modules exist; no models). These are the highest-priority
  additions — semantic reranking for RTL users currently does nothing.

## Phases

1. **Enumerate** the intersection; rank by (existing gem module,
   speaker base, dictionary size). ar, fa, he lead.
2. **Ship in priority order under a compute budget** — same pipeline,
   same gates (fluency rank_corr ≥ 0.97 / top1 ≥ 0.95, mini ≥ 0.90 /
   0.85), same keyboard-aware eval. Extend `eval/noise.py` per
   language as needed (Hebrew/Arabic grids; reuse wave-1 patterns).
   Target ≥ 15 shipped in this batch (ar fa he + a dozen more);
   record the remaining tail in the registry README as the backlog.
3. **fi / id dictionaries** — not in the dictionaries repo. Source
   from upstream (LibreOffice/hunspell releases) INTO the
   dictionaries repo with license metadata per its manifest schema;
   then run them through the same pipeline. LICENSE VERIFICATION IS
   A HARD GATE — if provenance is unclear, skip and report.
4. **`no` → nb/nn mapping** — proposal only: registry aliases or gem
   resolution mapping `no` to `nb` (Bokmål). Owner decision; do not
   implement unilaterally.
5. **Release v1.2.0** (plan 05 policy: coverage = minor), 3 tiers per
   new language, media-host mirrors, byte-identical registry proof.

## Owner gates

- `no` mapping decision (proposal delivered, not executed).
- Version follows the plan-05 pre-declared policy as v1.1.0 did.

## Status

**Implemented (2026-09-05, models PR #14 + tag v1.2.0).** 22 -> 54
languages (32 shipped: fa he ar id hy hr bg sr sk mn lt ka ne nn sl
mk lv et tk la gl eu cy eo is lb fy br ga gd oc ia), 162 registry
resources rev 3, 326 assets, byte-identity proven. ar/id
dictionaries sourced with verified licenses (dictionaries PRs #1-#3,
that repo's default branch is v1). Gates never weakened. DROPS:
nds (ISO 639-2-only vs the two-letter schema contract - owner spec
decision), fi (no license-clear upstream - hard gate), fo rw ie fur
tlh (no fastText CC vectors). BACKLOG EMPTY: every dictionaries
language FastText can serve ships. Owner proposal pending: no->nb/nn
(cc.no as Bokmal-labeled nb + gem resolves no->nb).
