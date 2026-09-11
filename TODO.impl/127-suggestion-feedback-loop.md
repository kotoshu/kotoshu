# Plan 127 — Report-a-wrong-suggestion: backendless feedback loop

Status: pending
Depends on: the 2026-09-11 recommendation (real failure reports feed
plan 123's corpora; DeepSeek's environments-from-real-failures lesson)

## Problem

The playground is our only surface where real users meet real
suggestions, and when a suggestion is wrong the feedback evaporates.
Plan 123 synthesizes pairs; the higher-value stream is REAL wrong-
suggestion reports, and capturing them needs no backend: a GitHub
issue prefill carries the diagnostic.

## Fix

- Playground suggestion popover gains a small "report" affordance on
  each row: opens github.com/kotoshu/kotoshu/issues/new?title=... with
  a body template containing the word, the offered suggestions, the
  language, the engine version, and (already public) tier info — no
  page content, no user text beyond what the user chooses to add.
- The issue template lands in the gem repo (.github/ISSUE_TEMPLATE/
  wrong-suggestion.md) so reports arrive structured; a triage note
  points verified pairs at eval/corpora for the next reprice.

## Acceptance

- One click from a wrong suggestion to a structured, pre-filled issue.
- No PII beyond the single word the user is already looking at; the
  template says so.
