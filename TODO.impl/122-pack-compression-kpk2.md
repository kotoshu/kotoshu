# Plan 122 — KPK2: compressed pack sections

Status: executed as REJECTED on the pre-declared gate (2026-09-12 measurement)

zstd-19 per-section, en-1.5.0.bin (15,173,525 bytes):

    aff      3,086 ->     908  (3.40x)
    dic    551,762 -> 169,700  (3.25x)
    model 3,040,752 -> 2,769,252 (1.10x)
    vocab  202,597 ->  59,342  (3.41x)
    buckets 11,375,135 -> 9,854,872 (1.15x)
    total             -> 12,854,074 (84.7% of KPK1)

The acceptance gate was <= 60%. The pack is 75% int8 bucket table and
20% int8 ONNX weights — nearly incompressible; the sections that win
3.4x are 5% of the bytes. A 15% wire saving does not pay for a format
generation, a decompressor on the wasm surface, and a registry
re-cut. Revisit only if buckets shrink or sub-int8 quantization lands
(the thing that would actually move the 84.7%).
Depends on: plan 113 (KPK1), the 2026-09-10 model-efficiency research

## Problem

KPK1 packs ship raw sections: en-1.5.0.bin is 15.2 MB over the wire
(aff+dic text ~1.2 MB, int8 ONNX ~12 MB, vocab JSON, buckets). The
text/JSON sections compress ~5-10x; the int8 weights ~1.2-1.5x. The
playground's first-load cost is dominated by bytes that decompress in
microseconds — costs are being paid in the expensive dimension
(bandwidth) instead of the cheap one (CPU). Same pattern as
DeepSeek-V4.1-Flash storing KV in FP4 and dequantizing before
attention: compress storage, not compute.

## Design

- KPK2 container: same section framing as KPK1 (magic+count, framed
  sections, sha256 footers) with (a) a new magic version byte, (b)
  each section optionally zstd-frame-compressed, flagged by a new tag
  bit; uncompressed sections remain valid — readers negotiate on the
  magic, never on heuristics.
- Engine side (`kotoshu-rs`): `ruzstd` (pure-Rust decoder, no C
  dependency — wasm-safe). Decompress per section before sha verify?
  **No**: keep the footer sha over the COMPRESSED bytes so corruption
  detection happens before decompression; the KPK1 golden-sha parity
  test gains KPK2 twins.
- Builder side (`models-fasttext-onnx`): pack builder emits KPK2 with
  zstd level 19 for text/JSON sections, raw-or-zstd for int8 weights
  (measure; ship whichever wins per section).
- Registry: `kotoshu://packs/{lang}` entries gain the new artifacts;
  bump registry to v1.7.0 per plan 05 policy; mirrors must serve both
  generations during the rollout window.
- Consumers: wasm `loadPack` (versioned by magic), worker pack mode,
  playground pin bump, site caching-docs truth.

## Acceptance

- en pack wire size measurably smaller (target: ≤ 60% of KPK1;
  report actual), loadPack wall time within +10% of KPK1 (143 ms
  baseline on M-series).
- Conformance: KPK1 packs still load unchanged (back-compat gate).
- Registry v1.7.0 released with both generations mirrored.

## Execution order (next session)

models builder → rs engine + wasm 1.1.0 → registry v1.7.0 →
worker/playground flip → site docs+news. The LFS upload pipeline is
the long pole (historically ~1h with CDN throttles) — start it first.
