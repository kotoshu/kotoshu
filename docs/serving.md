# Serving laws — measured rules for gating and shipping models

Every law here was learned by paying for its violation. When a new
model lands, these apply without re-litigating.

## Gate before publish — one metric, one path

- **Publish only if the gate beats the published number through the
  SHIP decode path in the SHELF metric.** The shelf metric is the
  factory corruption-gold F0.5 (`factory/gold_score.py`); the ship
  decode path is the exact serving pipeline (SpmBpe for spm-family
  artifacts, ByteBpe/HF for roberta-family) at the shipped round count.
- Never mix metrics across a comparison. Exact-match vs F0.5 is the
  error that mis-scored a whole encoder decision (2026-11-20).
- **Assert sources != gold before believing any ~100% gate result.**
  The deberta-ur "1.000" was a clean-input decode compared against its
  own gold (2026-11-20).

## Training recipes

- deberta-v3-family: **slow-spm tokenizer + per-word alignment**
  (`train_gector_hf.py` does this automatically for deberta) — the
  converted fast tokenizer drops byte fallback and misaligns serving.
  mdeberta diverges 0/300 ur lines; deberta 41/300. Train what serving
  produces.
- **`--max-len 128` for byte-fallback tokenizers.** The 96 default
  truncated 8.7% of pack rows (labels cut, tail fixes never trained).
- 3-round schedule (4ep vanilla + 2ep KEEP-weighted @ LR/10, keep 0.3)
  helps fresh trains. **Never resume-and-extend a converged model** —
  en-r23 measured −1.8pt doing exactly that.
- Teacher-exact rows dilute for ko/ja but won for ru — always gate the
  mix against the published number before believing a data thesis.

## Packaging

- **deberta ships int8-free.** `quantize_dynamic` collapses deberta
  activations (0 edits on the whole gate); mdeberta tolerates it. The
  deberta path is `scripts/cast_fp16_onnx.py`: fp16 weight storage +
  Cast-to-fp32 nodes, ~184MB, sound ops on arm64 and x86 (verified).
- mdeberta ships the dequantized fp32 weights (~457-473MB class).
- **Pruned artifacts serve via SpmBpe only** (`pieces.json` +
  `charsmap.json`). A present `tokenizer.json` forces HF dispatch,
  which emits original-id space and OOBs on pruned embeddings. The
  mdeberta charsmap differs from deberta's — each ships its own.
- Parity gate runs on every package; the gate script must count
  unmapped ids before any pruned-vs-full delta is believed
  (old2new.get(i, UNK) fabricates deformation).

## Decoding

- **MIN_CONFIDENCE is per-model** (issue #292): the 0.3 default
  over-fires; mc0.5 lifted both slices on the cjk v9 line. Calibrate on
  the gate slice and record the default on the card.
- ROUNDS>1 compounds argmax noise in uncalibrated decoders — R4 scored
  below R1 on the deberta-ur gate until calibration exists.

## Compliance (CLE-adjacent languages)

- Schedule D attribution verbatim on the card ("Training data"
  section) — see pk-cle-urdu NOTICE-TEMPLATE.md.
- **Clause 16(e) gate (`scripts/clause16e_gate.py`) before any
  CLE-adjacent release**: memorization ≥25-word threshold, membership
  AUC, completion-surface absence, WordNet leakage. Run record kept.
- Schedule C prohibited list governs derived artifacts: standalone
  word/frequency lists are prohibited; compiled spell-checker
  dictionary packages are permitted with the gates.
- Measurement law for CLE gates: the corpus is processed locally only;
  nothing from pk-cle-urdu is uploaded anywhere.
