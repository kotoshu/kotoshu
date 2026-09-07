# Plan 100 — Full-feature language batch 3: the highest-audience remainder

## Why
20 languages are full-feature (gem module + keyboard layout + verified
specimens); the dictionaries manifest and the model registry carry ~35 more
with both resources. Every remaining language without a module leaves
speakers on the degraded path. The gaps are the big-audience ones: ar (~400M),
id (~200M), fa (~80M), he, bg, sr, hr, sk, sl, and more.

## Work (gem repo only — the site flip rides a follow-up)
1. Enumerate: languages present in BOTH the dictionaries manifest and the
   models registry that lack a gem module. Rank by speaker count.
2. For the top ~12 (expected: ar id fa he bg sr hr sk sl lt lv et — confirm
   against data): create the language module (pattern of the 19 from PR
   #123), keyboard layout (Arabic 101 for ar; Persian for fa; Hebrew for he;
   Cyrillic/YUSI for bg/sr; QWERTZ/Slovak for the Latinate), AVAILABLE_LANGUAGES
   extension, and specimen pairs verified against the STAGED dictionary via
   the real engine (correct()/suggest() round trips) — the PR #123 discipline.
3. RTL already wired (ar/id from batch 2); no tokenizer work needed.
4. Suite green; rubocop clean.

## Verification
One spec per module (specimen corrections engine-verified, layout smoke);
`kotoshu setup <lang>` + `check -l <lang>` exercised live for at least ar,
id, fa, he. Deliver the verified specimen table + sizes for the site flip.

## Status

**Implemented 2026-09-07 (gem PR feat/full-feature-batch3).**
Enumeration confirmed from the data: the v1 dictionaries manifest (95
languages, 285 resources) intersected with the models registry v1.3.0
(55 languages) minus the 20 full-feature languages leaves 30
candidates; ranked by speakers with ko/ne excluded (CJK Hangul jamo
input and Devanagari need ja-style tokenizer work outside this
batch), the top 12 landed: ar (~400M) id (~199M) fa (~80M) he bg sr
hr sk sl lt lv et. All 12 staged dictionaries parse through the real
engine (no aff flag failures). Six national key grids mirrored from
the models repo eval harness plan 83 batch-2 grids (Arabic 101,
Persian ISIRI 9147, Hebrew SI-1452, Bulgarian BDS, Serbian Cyrillic,
Croatian/Slovenian QWERTZ) with the drift fixture extended to all
nine national grids; five Latin members (id sk et lt lv) ride the
parameterized qwerty family like the eval model. AVAILABLE_LANGUAGES
20 -> 32. Verification exposed a real gap: the check path
(Kotoshu.check / kotoshu check -l) extracted zero RTL words because the
ar/fa/he tokenizers lacked the plan-91 spellcheck_word_regex override -
added per the Greek/Cyrillic pattern (fa includes ZWNJ, which the
staged dictionary carries in 48k forms). 55 specimen pairs engine-verified (correct?/suggest round
trips, RTL sentences included); the verified pairs live in a
:network spec and in the PR body for the site flip. sr-Latn stays
unwired like nn; ko and ne are the top deferred candidates.
