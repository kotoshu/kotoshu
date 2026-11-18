# 152 — deberta-v3 sentencepiece port (the ≤250MB encoder upgrade)

## Thesis
The owner's model-size ceiling is ≤250MB. mdeberta int8 lands ~420-460MB.
deberta-v3-base int8 ≈ 187MB — fits — and every measured campaign
artefact (ru/cjk/de recipes) shows deberta ≥ mdeberta quality. The
blocker: deberta's sentencepiece vocab (250k) must be servable from Ruby
without the Python runtime — a Ruby sentencepiece unigram/BPE port that
matches the prune_export pipeline's tokenizer bit-for-bit.

## Plan
1. [x] Survey (2026-11-19): the FULL deberta unigram table SURVIVES —
   ~/.cache/kotoshu-gec/models/de-v1/pieces.json.bak-79649 holds all
   79,649 pieces {piece, score, type} (the pre-prune vocab). The Ruby
   port needs: protobuf-free unigram Viterbi encode over that table +
   byte-fallback (type-6 <0xNN> pieces) + the deberta pre-tokenizer
   (none) + [CLS]/[SEP]/[UNK] specials (types 3/2). No .proto decode
   needed — the table is already extracted, and ALL 79,289 type-1
   pieces carry their log-scores (Viterbi-ready, verified 2026-11-19).
2. [x] Ruby port DONE (2026-11-19): SpmUnigramEncoder — global Viterbi
   over the ▁-transformed string + byte-fallback; **8/8 conformance**
   vs the rebuilt-proto oracle (scripts/rebuild_spm_proto.py — proto
   reconstructed from the table, byte_fallback=true). Fix en route:
   scores are log-probs verbatim, Math.log of them = NaN = garbage paths.
3. [ ] Conformance: export encode vectors from the Python tokenizer,
   replay gate in Ruby (the #259/plan-131 pattern)
4. [ ] Re-train OR re-package an existing deberta checkpoint through
   the Ruby tokenizer → parity gate → cross-arch confidence check
5. [ ] Publish per language (ru/cjk candidates first — published
   models shrink ~50%)

## ETA
2-3 days (port ~1.5, conformance ~0.5, repackage/gates ~0.5).

## Status
- [ ] survey
- [ ] port
- [ ] conformance
- [ ] repackaged + gates
