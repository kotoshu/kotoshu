# 150 — Multilingual full-feature wave (Urdu template × Latin languages)

## Thesis
The Urdu campaign produced a complete, proven template: corruption
pack builder (balanced language-specific classes) → resilient 3-round
train → package → held-out gate → 16(e)-style release checks. The
dictionaries repo already carries licensed hunspell dictionaries for
~96 languages — corruption word sources are already licensed.

## Wave 1 (Latin phonetic, qwerty-adjacent — lowest template cost)
it · nl · pl · pt — module files mirror `languages/latin_base`, packs
from the ur_pack_build.py pattern (keyboard adjacency + transpositions +
space + real-word swaps grounded in each language's dictionary).

## Per language (½ day each, boilerplate after the first)
- [ ] languages/{code}/language.rb (latin_base subclass)
- [ ] corruption pack (private staging, provenance + SHA256SUMS)
- [ ] dictionary package → dictionaries repo + manifest regen
- [ ] train 3-round → package → held-out gate
- [ ] StagedLanguages sync

## Wave 2 (defer, needs per-script work)
ar/fa/he (Arabic-script like ur — need per-language layouts) ·
hi/bn (Devanagari — layout exists, pack classes TBD) ·
el/uk/tr/sr (national layouts exist from plan 84/100).

## Fence
Everything ships as weights/code/dictionary-packages only (per-license
Schedule-C-equivalents); packs stay private with provenance.
