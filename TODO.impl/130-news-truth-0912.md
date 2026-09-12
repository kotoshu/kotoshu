# Plan 130 — News truth: the 1.0.1 patch and the 09-12 wave

Status: pending
Depends on: plans 119/121 (1.0.1 content), 123/125/126/127

## Problem

Two shipped changes have no news entries: gem 1.0.1 (embedded frozen
tiers, Jekyll sweep skip) and the 09-12 wave (corpora, error budgets,
the feedback loop, the docker image fix). The site's discipline is one
entry per user-visible change.

## Fix

- One entry for 1.0.1 (determinism by construction: cache-cold == warm
  == frozen vectors).
- One entry for the wave: corpora + the 1.5% typo-embedding finding +
  error-budget table + report-a-suggestion link.

## Acceptance

- Entries live, dates and version references truthful.
