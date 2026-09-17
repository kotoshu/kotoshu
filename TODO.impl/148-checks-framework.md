# Plan 148: the Checks framework - kotoshu is a content-quality checker

## Status: proposed (owner directive 2026-09-17: "we are a content quality checker... a spell check is one of the kinds of quality check, not ALL the checks. make it properly work")

## Principle

The engine becomes a composition of QUALITY CHECKS, each a first-class
class with the same contract; spelling is check #1, not the whole
product. Each check declares: id, the languages/scripts it applies
to, its model dependencies (which substrate resources it needs), its
calibration state (default-on only when its frozen-data FP budget
passes - the real-word arc's pattern), and produces findings TYPED by
check kind. The API/LSP/action surfaces carry check kinds natively
instead of everything masquerading as spelling.

## The framework (OCP: a new check is a registration, not surgery)

- Kotoshu::Checks::Base - the contract (applies_to?, dependencies,
  run(document) -> [Finding]).
- The registry composes checks whose dependencies are satisfied for
  the active language; missing models degrade to check-absent, never
  to engine-absent (the typo layer's pattern, generalized).
- Existing analyzers slot in: SemanticAnalyzer (spelling, default-on),
  the plan-146 real-word analyzer (opt-in until its gate passes),
  fluency-as-a-check (the fluency tier already ships as a model - it
  gains a check surface: register/fluency scoring per document), and
  grammar (GEC-class; data already researched - lang8_hsk 1.57M MIT
  pairs for zh, MuCGEC/CGED for the grammar class).
- Findings carry check_kind; /v1/check, the LSP diagnostics mapping,
  the CLI/report formats, and the action surfaces gain a kinds
  dimension (additive; today's consumers see spelling exactly as now).

## Gates

- The full suite green with the framework in place and spelling as
  the only default-on check (byte-identical outputs for existing
  callers).
- Each non-spelling check ships opt-in until its own frozen-data FP
  budget passes (mirrors plan 146's contract).
- The registry of checks is data-driven (a check list the server/CLI
  can enumerate) - discovery without code changes.

## Consumers

Plan 21 (the substrate) feeds every check; plan 146 (real-word) is
the second check to land under the framework; fluency-check and
grammar follow with their own calibrations.
