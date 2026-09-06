# 20 — Encapsulation cleanup (T3, deferred past 0.3)

## Status
Deferred past 0.3 release. Documented for 0.4.

## Problem
The codebase has three categories of encapsulation violations prohibited
by `~/.claude/CLAUDE.md`:

| Violation | Count | Source |
|---|---|---|
| `obj.send(:private_method, ...)` | 4 | breaks private boundary |
| `instance_variable_set` / `instance_variable_get` | 21 | breaks encapsulation of another object's state |
| `respond_to?(:method)` for type checks | 24 | hides type errors until runtime |

New code in 0.3 follows the rules; this file tracks migrating the
existing violations.

## Plan

### send to private (4 occurrences)
Each call site is a design smell — the API boundary is wrong. Fix per
location by either:
- Making the method public (if callers outside genuinely need it).
- Adding a public method that does what the caller wants (rename intent).
- Inlining the call at the (usually single) call site.

### instance_variable_set / instance_variable_get (21)
Replace each with a public accessor or a constructor argument. If the
target object genuinely needs to be mutated externally, expose a public
setter that maintains invariants.

### respond_to? for type checks (24)
Replace with `is_a?(SpecificType)` or — better — redesign so the type
hierarchy makes the check unnecessary (polymorphism).

## Acceptance

- [ ] `grep -rn "\.send(" lib/ | wc -l` is 0 (or all remaining are
      legitimate metaprogramming, with an inline comment justifying each).
- [ ] `grep -rn "instance_variable_set\|instance_variable_get" lib/` is 0.
- [ ] `grep -rn "respond_to?" lib/` returns only duck-typing cases that
      have been audited and have an inline comment.

## Why deferred
Touching 49 call sites risks regressions in working code. 0.3 priority
is user-facing usability. Sweep this in a dedicated 0.4 PR.
