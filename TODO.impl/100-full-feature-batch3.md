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
Pending
