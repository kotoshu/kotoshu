# 26 — Generate .vocab.json for 9 active ONNX models (T1, 0.3-blocker)

## Status
Implemented — and superseded in scope (re-verified 2026-09-03 against 0.6.0).

Evidence:

- `kotoshu/models-fasttext-onnx` now ships 27 `.vocab.json` files on
  disk (9 languages × 3 tiers: full/fluency/mini), e.g.
  `models/en/fasttext.en.vocab.json`, `models/en/fasttext.en.mini.vocab.json`;
  `manifest.json` carries them with `"type": "vocab"` entries.
- Gem side consumes them: `lib/kotoshu/embeddings/vocabulary.rb`
  (`Embeddings::Vocabulary.from_file` line 137, `.from_cache` line 269)
  and `Models::OnnxModel.from_file` requires the `.vocab.json` sibling
  (`lib/kotoshu/models/onnx_model.rb:86-93`).
- Cache side: `SourceRegistry` has a `model_vocab` source and
  `ModelCache` fetches vocab siblings with SHA-256 verification against
  the registry (`lib/kotoshu/cache/model_cache.rb`).

Superseded: the "9 flat models" world was replaced by the tiered
registry (registry.json, mini/fluency/full — TODO.impl/67 M1), so the
plan's manifest-with-18-entries shape no longer applies.

Not re-verified live today: `Kotoshu.setup(:en, want: %i[model])`
(114 MB download; `kotoshu status` shows model ✗ in the dev cache).

## Problem
The 9 active ONNX models in `kotoshu/models-fasttext-onnx` have no
`.vocab.json` siblings:
```
models/de/fasttext.de.onnx          # 114 MB
models/de/fasttext.de.vocab.json    # MISSING
```

`OnnxModel.from_file` in the gem requires both files — the `.onnx` holds
only the embedding matrix; word → row index lives in `.vocab.json`.
Without it, every semantic lookup crashes.

The conversion script changes I made earlier (always emit vocab.json)
were post-hoc — they apply to FUTURE conversions, not the existing 158
files on disk.

## Plan

### Step 1 — Add a vocab-only extraction script
New script `scripts/extract_vocab_from_vec.py`:
- Input: FastText `.vec` file path + vocab size (default 100K)
- Output: `<stem>.vocab.json` matching the format emitted by
  `fasttext_to_onnx.py`'s `save_vocabulary()`.

This is faster than re-running the full ONNX conversion (which would
also re-emit the 114 MB .onnx unnecessarily).

### Step 2 — Download the 9 source .vec files from FastText CDN
~7 GB total (compressed .vec.gz, ~700 MB per language). Cache under
`/tmp/fasttext-vec/` so re-runs don't re-download.

For each active language (de, en, es, fr, pt, ru, zh, ja, ko):
```
curl -O https://dl.fbaipublicfiles.com/fasttext/vectors-crawl/cc.<lang>.300.vec.gz
gunzip cc.<lang>.300.vec.gz
python3 scripts/extract_vocab_from_vec.py cc.<lang>.300.vec \
    --vocab-size 100000 \
    --output models/<lang>/fasttext.<lang>.vocab.json
```

### Step 3 — Verify vocab.json matches the existing .onnx
Each `.onnx` has `vocab_size` in its metadata. The `.vocab.json` must
have the same `vocab_size` AND the word order must match what was used
to build the embedding matrix. This is the load-bearing correctness
check — a mismatch makes embeddings return wrong vectors.

Verify by spot-checking a known word (e.g. "the" in en) and confirming
the embedding matches a reference value.

### Step 4 — Regenerate manifest + commit + push
The 9 new `.vocab.json` files get added to `manifest.json` via the
existing `generate_manifest.rb` script.

## Acceptance

- [ ] 9 `.vocab.json` files committed under `models/<lang>/`.
- [ ] `manifest.json` includes 18 entries (9 .onnx + 9 .vocab.json).
- [ ] Gem's `AVAILABLE_MODELS[:onnx]` unchanged (no code change).
- [ ] Live: `Kotoshu.setup(:en, want: %i[model])` succeeds.
- [ ] Live: `Kotoshu::Models::OnnxModel.from_file(...)` returns a working
      model that can produce an embedding for "the".

## Dependencies
- None (independent of gem code).

## Risks
- 7 GB download may saturate a metered connection. Run on a connection
  without caps.
- Vocab ordering mismatch with original conversion would silently
  corrupt semantic results. Must verify by embedding spot-check.
