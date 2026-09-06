# 59 — YARD API documentation

## Goal

Public kotoshu APIs are essentially undocumented. The codebase has
YARD-style docstrings on many methods but no published API docs,
and many public methods lack docstrings entirely.

## Current state

- `bundle exec yard` works locally (if yard is installed)
- No `docs/` build pipeline in CI
- No gh-pages deployment
- Many public classes/methods lack `@param` / `@return` / `@example`
  tags.

The README.adoc is user-facing; YARD docs are the contributor/dev
surface.

## What needs doing

### Phase 1 — Inventory public API

Identify which classes/methods are part of the public API (vs
internal). Heuristic:
- `Kotoshu.*` module methods are public.
- Classes in `lib/kotoshu/` whose methods are documented as
  public-facing (`Kotoshu.correct?`, `Spellchecker#check`, etc.)
  are public.
- Classes marked `@api private` or in clearly internal namespaces
  (e.g., `Grammar::PatternMatchers::*`) are internal.

Output: a list of public API methods that need full YARD docs.

### Phase 2 — Write docstrings

For each public method:
- Add `@param` for every parameter.
- Add `@return` describing the return value.
- Add `@example` for non-trivial methods.
- Add `@raise` for any raised exceptions.
- Mark internal helpers `@api private`.

### Phase 3 — CI integration

- Add a `docs` job to `.github/workflows/ci.yml` that runs
  `bundle exec yard --no-output`. Fails on warnings.
- Optional: deploy to gh-pages on tag pushes.

## Acceptance criteria

- [ ] Every public method has YARD docstring with `@param` and
      `@return`.
- [ ] `bundle exec yard --no-output` exits 0 (no warnings).
- [ ] CI runs YARD check on every PR.
- [ ] (Optional) gh-pages site at `kotoshu.github.io/kotoshu` or
      similar.

## Why this matters

- **Discoverability.** New users can't easily learn the API from
  source alone.
- **Editoring.** IDE intellisense uses YARD types when available.
- **API contract.** Docstrings force authors to think about what
  the method promises.

## Dependencies

- **Blocked by:** none (independent of code changes).
- **Blocks:** nothing (long-running cleanup).

## Out of scope

- Tutorial-style documentation (lives in README.adoc and `docs/`).
- Architecture decision records (lives in `docs/adr/` if added).
