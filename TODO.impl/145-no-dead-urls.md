# Plan 145: no dead URLs leave the library

## Status: executed

## Problem

Plan 144 fixed `Dictionaries::Catalog`'s `/main` URLs (the dictionaries
repo lives on `v1`). The sibling audit found three more places the
library could hand a user a dead URL:

1. `ModelCache#model_url`'s defensive else-branch built
   `dictionaries/main/…/models/…` — a path that 404s on two counts
   (wrong branch, and the dictionaries repo never hosted models).
2. The deprecated `dictionaries_url` knob's DEFAULT pointed at the
   dead `/main` branch — a trap for anyone reading or copying it.
3. `Dictionary::PlainText`'s docstring example used the dead URL.

## Changes

- The else-branch raises `Kotoshu::Error, "unknown model type"` —
  honest failure instead of a 404 URL (unreachable from the public
  API today; the guard is for future internal callers).
- `dictionaries_url` default: `/main` → `/v1` (knob stays deprecated).
- Docstring URL truthed.
- Spec: the configuration default ends in `dictionaries/v1`.

## Evidence

- 23 examples across the two touched suites, 0 failures; rubocop
  clean.
- Audit: `dictionaries/main` no longer appears in `lib/` outside the
  SourceRegistry's flat-layout template (which interpolates the v1
  pin).

## Sister

Plan 144 (#212) fixed the live Catalog URLs; lsp #8 the engine floor.
