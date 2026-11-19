# 150 — Multilingual full-feature wave (Urdu template × Latin languages)

## Wave-1 GATE VERDICTS + PUBLISHED (2026-11-19 morning)
- **grammar-pt PUBLISHED: F0.5 0.5705 (P 0.689 R 0.338), 1,467 pairs**
- **grammar-nl PUBLISHED: F0.5 0.565 (P 0.954 R 0.215), 1,458 pairs —
  the precision standout of the shelf**
- **grammar-pl PUBLISHED: F0.5 0.4178 (P 0.427 R 0.385), 1,490 pairs —
  balanced profile, in the ru band**
All three: first-ever published models for these languages in the
ecosystem; arm64-local decoded from the shipped artifacts (the x86 eval
job died silently — the arm64 chain is the gate law), corruption-gold
scorer, held-out splits never trained on. Cards carry recipe +
provenance. it lane still training (a10g preempt churn).
Reference band: fr 0.811 · es 0.620 · ur 0.640 · pt 0.571 · nl 0.565 ·
ru 0.422 · pl 0.418.

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
- [x] languages/{code}/language.rb (latin_base subclass) — ALL FOUR
      pre-exist from plan 84 wave-1 (it/nl/pl/pt thin LatinBase modules)
- [x] corruption pack (private staging, provenance + SHA256SUMS)
      2026-11-18: nl 40,943 / pl 48,628 / pt 41,803 pairs, balanced
      classes, density-gate PASS (1.00 edits/sent, REPLACE-dominant);
      it building (647k-sentence corpus, base_it.txt Oct-21 web-domain)
      Sentence sources: nl/pl/pt via the wikisource STATIC DUMP fetcher
      (scripts/wikisource_dump_fetch.py — the API walker stays
      IP-throttled; dumps.wikimedia.org is unthrottled), ~400k words
      each with page-title provenance manifests
- [x] eval splits: {lang}_heldout_eval_sources.txt + _gold.tsv
      (held-out clean sentences corrupted with the same builder classes,
      fixed seed; uploaded to kotoshu/kotoshu-code data/)
- [ ] dictionary package → dictionaries repo + manifest regen (dictionaries
      already present for all four — verify package.json manifests only)
- [x] train 3-round fired (2026-11-18, l4x4, mdeberta bf16, rounds 3 ×
      [4ep s1 + 2ep s2], keep 0.3, per-run GEC_DATA_ROOT/GEC_CKPT_DIR,
      ckpt kotoshu/gec-ckpt-{lang}-v1): nl/pl/pt v1c in flight; it fires
      when its pack lands → package → held-out gate
- [ ] StagedLanguages sync

## Recipe notes (2026-11-18)
- The ro-mount law: jobs mounting scripts:/app:ro must set
  GEC_DATA_ROOT=/d2 (data exists as mounted) AND GEC_CKPT_DIR=/tmp/ckpt
  (the trainer's relative 'ckpt' default is unwritable) — v1a/v1b died
  on exactly these.

## Wave 2 (defer, needs per-script work)
ar/fa/he (Arabic-script like ur — need per-language layouts) ·
hi/bn (Devanagari — layout exists, pack classes TBD) ·
el/uk/tr/sr (national layouts exist from plan 84/100).

## Fence
Everything ships as weights/code/dictionary-packages only (per-license
Schedule-C-equivalents); packs stay private with provenance.
