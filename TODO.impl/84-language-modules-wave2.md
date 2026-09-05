# 84 — Language modules + keyboards for the 22 model languages

## Context

The models registry now serves 22 languages, but gem language modules
exist for only 10 (ar de en es fa fr he ja pt ru) and keyboard layouts
for 5 (azerty dvorak jcuken qwerty qwertz). A Turkish user gets a
model but no Turkish-Q keyboard proximity; Greek, Ukrainian, Polish,
Czech, Hungarian, Nordic users likewise. The site honestly labels this
gap ("staged dictionary + model until the module is wired") — close it.

## Track A — keyboard layouts

New layouts in `lib/kotoshu/keyboard/layouts/`: tr (Turkish-Q), uk
(ЙЦУКЕН Ukrainian — extends jcuken with ҐЄІЇ), el (Greek), pl, cs,
hu, da/nb/sv (Nordic shared layout with per-language diacritics), ro,
ca, it, nl (Latin layouts parameterized over the qwerty/qwertz base —
prefer ONE parameterized Latin layout family + per-language key maps
over 11 near-duplicate files; keep the existing five as-is).

**Single source of truth**: the models repo's `eval/noise.py` grids
(wave-1 added Turkish-Q / Ukrainian-JCUKEN / Greek-phonetic) encode
the same adjacency data — derive the gem layouts to match them and
record the sync note in both repos' plans (drift check: a spec
asserting the gem layout keys ⊇ the eval grid keys for tr/uk/el).

## Track B — language modules

`lib/kotoshu/languages/` modules for the 13 wave-1 Latin newcomers
(ca cs da el hu it nl pl ro sv tr uk vi): most are thin — Latin
tokenizer/normalizer composition + layout + registry entry. Follow the
existing module pattern (see `de`, `pt`); el gets Greek-aware
normalization; tr gets case-folding care (dotless i); vi may reuse
Latin defaults. Each module ships with specs against real dictionary
fixtures (no doubles).

## Track C — site truth (executed by the site agent, not here)

Full-feature list grows; the "staged + model" note shrinks. Recorded
here as the dependency so the site agent can sequence on this PR.

## Constraints

- No behavior change for the existing 10 modules.
- `register_suggestion_algorithm`/layout registry patterns unchanged
  (OCP: layouts register, nothing edits a switch).
- Suite stays green; add specs per layout + module.

## Status

**Pending.**
