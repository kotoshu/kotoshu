# 75 — LLM-as-Evaluator (adopt-later C4)

From [68-sota-adoption.md](68-sota-adoption.md) item C4. LLM-as-GEC-
evaluator is standard practice in the literature
([BEA 2024](https://aclanthology.org/2024.bea-1.6/)).

## Goal

Augment the eval harness with an optional LLM judge that scores tier
outputs where our proxy metrics are weakest: fluency of the corrected
sentence and overcorrection risk — dimensions cosine hit rates cannot
see. Strictly offline tooling for model selection; never a release
gate (no API dependency in CI), never runtime.

## Tasks

1. `eval/llm_judge.py` — takes candidate corrections + references,
   prompts a judge model (API, user-provided key via env; never
   committed), produces per-language fluency/overcorrection scores
   appended to a SEPARATE report file (eval/reports/llm-judge.*.json),
   clearly marked non-deterministic.
2. Prompt + rubric documented in-repo; judge model + version recorded
   in every report.
3. Cost cap per run (pair count × languages), hard default small
   (e.g. 100 pairs/language) — a full sweep needs explicit flags.

## Acceptance

- Runs only with an explicit env key + opt-in flag; reports carry
  model/version/cost metadata; zero effect on gates or CI.

## Status

_Planning — low priority._ Proxy metrics suffice until corpora-driven
work (72–74) lands.
