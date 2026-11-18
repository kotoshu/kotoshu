# 152 — deberta-v3 sentencepiece port (the ≤250MB encoder upgrade)

## Thesis
The owner's model-size ceiling is ≤250MB. mdeberta int8 lands ~420-460MB.
deberta-v3-base int8 ≈ 187MB — fits — and every measured campaign
artefact (ru/cjk/de recipes) shows deberta ≥ mdeberta quality. The
blocker: deberta's sentencepiece vocab (250k) must be servable from Ruby
without the Python runtime — a Ruby sentencepiece unigram/BPE port that
matches the prune_export pipeline's tokenizer bit-for-bit.

## Plan
1. [ ] Survey: what deberta-v3-base actually needs (sentencepiece
   unigram model, byte-fallback, pre-tokenizer = none) — check
   spm.model of the existing de-v3 recipe artifacts (task #225/#233
   trained deberta models already — their tokenizers exist!)
2. [ ] Ruby port: load SPM proto (protobuf decode), implement
   unigram Viterbi encode + byte-fallback — the gem's byte_bpe.rb is
   the pattern precedent (plan: same spec/conformance-vector approach)
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
