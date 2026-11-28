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

## Job-fire and mount laws (HF Jobs)

- **Job mounts read the WORKING TREE, through a never-delete bucket
  cache.** Two failure modes this caused: (1) a stale local main ref
  silently packaged with missing files (registry FileNotFoundError) —
  always `git fetch origin main` and sync the tree before firing;
  (2) campaign-only scripts absent from main ran as STALE BUCKET copies
  from earlier fires (the pre-fix rebuild failed the bit-exact remap) —
  every script a job needs lands on main first (cast_fp16_onnx,
  rebuild_pruned_pieces: same class, both fixed).
- **SCHEDULING rows are invisible in `hf jobs ps` AND `ps -a`** (like
  terminal-row dropping). A fire that "produced no id" may be a QUEUED
  fire that starts hours later when a slot drains — refiring it creates
  a duplicate lane that races the same ckpt-vol. Attribute duplicates
  by SUBMIT ORDER (the fire task's output ids flush on completion),
  never by runtime (a queued job's runtime measures start, not submit);
  cancel the duplicate BY EXACT ID.
- **Terminal set is exactly {COMPLETED, ERROR, CANCELED}** — SCHEDULING
  is not terminal; watchers must filter on the explicit set.

## Runner-era laws (shelf-completion campaign, 2026-11)

- **Heavy loads run on HF Jobs — never on the workstation.** Gate
  decodes, calibration sweeps, perf measurements, trains: all are
  runner jobs (ruby:3.4 + `gem install kotoshu onnxruntime` Linux
  prebuilts, tree ruby code via `-I/app/lib`). The workstation is for
  file and spec work only.
- **HF list_jobs() exposes NO usable name attribute.** Watch jobs by
  ID PREFIX; capture the `id=` line of each fire into a watch file.
- **Job containers are ephemeral.** Every artifact a gate produces
  (decoded output, score JSON) uploads to kotoshu/gec-artifacts before
  job end, or it is lost. The hub library uploads work from jobs; the
  local python httpx2/brotli stack breaks large DOWNLOADS — download
  via curl against the resolve endpoint.
- **Segmenter laws for CJK decodes: ja decodes REQUIRE SEG.ja (suika)**
  — the whitespace fallback turns every Japanese line into one token
  and yields a vacuous zero; zh decodes REQUIRE the ZhSegmenter (and
  zh_segmenter.rb present in the mounted tree). ko decodes direct.
- **Rule-content law (PatternRule):** the matcher swaps the listed word
  verbatim, so one rule must map one exact surface to its exact fix —
  multi-form word lists with a single replace entry suggest unchanged
  text for the unmapped forms. One rule per exact replacement pair.
- **Batch gate jobs withhold ALL output until the slowest slice
  finishes.** One job per slice beats multi-slice batches: logs stay
  visible and a stuck slice cannot hold others' results hostage.
