"""Rebuild SpmBpe pieces.json for a vocab-pruned mdeberta export.

After prune_vocab.py, embedding row i holds ORIGINAL id keep_ids[i] in
sorted-contiguous order — but tok.save_pretrained keeps the original-ids
tokenizer, so the shipped pieces.json is wrong (Gather out-of-bounds at
decode, 2026-10-09..11). This script recovers the mapping from the weights
themselves: pruned rows are bit-exact copies of full-checkpoint rows, so
row-lookup yields the true old-id order. No corpus retokenization, no
corpus-file identity risk.

Verifies before writing:
  - every pruned row matches exactly one distinct full-checkpoint row
  - recovered keep_ids are strictly increasing (sorted per prune contract)
  - tokenizer ids map to array indices: [CLS] -> 1, [SEP] -> 2, [UNK] present
    (SpmBpe hardcodes CLS=1/SEP=2)

Usage:
  python3 scripts/rebuild_pruned_pieces.py \
    --onnx ~/.cache/kotoshu-gec/models/de-v1/gec-tagger.int8.onnx \
    --full-ckpt ~/.cache/kotoshu-gec/de_v3_ckpt/model.safetensors \
    --tokenizer microsoft/mdeberta-v3-base \
    --out-dir ~/.cache/kotoshu-gec/models/de-v1
"""
from __future__ import annotations
import argparse
import json
import os
import shutil


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--onnx", required=True)
    ap.add_argument("--full-ckpt", required=True)
    ap.add_argument("--tokenizer", default="microsoft/mdeberta-v3-base")
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    import numpy as np
    import onnx
    from huggingface_hub import hf_hub_download
    from safetensors.numpy import load_file

    model = onnx.load(args.onnx)
    # 2-D 768-wide initializers include FFN weights (out,in) = (3072,768);
    # a small pruned vocab (e.g. deberta-ur: 2857 rows) is SMALLER than
    # that, so "largest" picks the FFN matrix. The embedding is the
    # largest candidate whose rows actually exist in the full checkpoint.
    full = load_file(args.full_ckpt)
    we_keys = [k for k in full if "word_embeddings" in k and full[k].ndim == 2]
    assert len(we_keys) >= 1, f"no word_embeddings matrix in {args.full_ckpt}"
    # deberta-v3 (ELECTRA-style) can carry a second generator embedding —
    # the tagger exports the ENCODER one
    enc_keys = [k for k in we_keys if "generator" not in k.lower()]
    emb_key = (enc_keys or we_keys)[0]
    full_emb = full[emb_key]
    if full_emb.dtype != np.float32:
        # int8/bf16 training artifacts dequantize losslessly into the fp32
        # rows the ONNX export carries; compare in one dtype
        full_emb = full_emb.astype(np.float32)
    print(f"full embedding: {full_emb.shape} {full_emb.dtype} ({emb_key})",
          flush=True)
    full_rows = {full_emb[i].tobytes() for i in range(full_emb.shape[0])}

    cands = [i for i in model.graph.initializer
             if len(i.dims) == 2 and i.dims[1] == 768]
    emb_init = None
    for c in sorted(cands, key=lambda i: -i.dims[0]):
        if c.dims[0] < 100:
            break
        rows = onnx.numpy_helper.to_array(c)
        if rows.dtype != np.float32:
            rows = rows.astype(np.float32)
        if rows[0].tobytes() in full_rows:
            emb_init = c
            break
    assert emb_init is not None, \
        "no 768-wide ONNX initializer matches full-checkpoint rows"
    emb = onnx.numpy_helper.to_array(emb_init)
    if emb.dtype != np.float32:
        emb = emb.astype(np.float32)
    print(f"onnx embedding: {emb.shape}", flush=True)

    row_to_old = {}
    for old in range(full_emb.shape[0]):
        row_to_old.setdefault(full_emb[old].tobytes(), []).append(old)

    keep_ids = []
    ambiguous = 0
    for i in range(emb.shape[0]):
        hits = row_to_old.get(emb[i].tobytes())
        assert hits, (f"pruned row {i}: no bit-exact match in full checkpoint "
                      f"({emb_key} {full_emb.shape} {full_emb.dtype}, "
                      f"onnx {emb.shape} {emb.dtype})")
        if len(hits) > 1:
            ambiguous += 1
            hits = [h for h in hits if h not in keep_ids]
            assert hits, f"pruned row {i}: ambiguous rows all consumed"
        keep_ids.append(hits[0])
    assert len(set(keep_ids)) == len(keep_ids), "recovered ids not unique"
    assert all(b > a for a, b in zip(keep_ids, keep_ids[1:])), \
        "recovered ids not sorted — not a prune_vocab.py export"
    assert ambiguous == 0 or print(f"note: {ambiguous} ambiguous rows resolved by exclusion", flush=True)
    print(f"recovered mapping: {len(keep_ids)} rows, "
          f"old ids {keep_ids[0]}..{keep_ids[-1]}", flush=True)

    import sentencepiece.sentencepiece_model_pb2 as sp_pb2
    from transformers import AutoTokenizer
    tok = AutoTokenizer.from_pretrained(args.tokenizer)
    spm_path = hf_hub_download(args.tokenizer, "spm.model")
    proto = sp_pb2.ModelProto()
    proto.ParseFromString(open(spm_path, "rb").read())
    # ids beyond the proto are ADDED tokens (mdeberta: [MASK] at 250,101)
    id_to_token = {i: t for t, i in tok.get_vocab().items()}
    pieces = []
    for old in keep_ids:
        if old < len(proto.pieces):
            p = proto.pieces[old]
            pieces.append({"piece": p.piece, "score": p.score, "type": p.type})
        else:
            pieces.append({"piece": id_to_token[old], "score": 0.0, "type": 4})

    names = [p["piece"] for p in pieces]
    assert pieces[0]["piece"] == "[PAD]" and pieces[1]["piece"] == "[CLS]" \
        and pieces[2]["piece"] == "[SEP]", \
        f"specials misordered at head: {names[:4]}"
    assert "[UNK]" in names and "[MASK]" in names, \
        "[UNK]/[MASK] missing from array"
    print(f"specials ok: [CLS]@1 [SEP]@2 [UNK]@{names.index('[UNK]')} "
          f"[MASK]@{names.index('[MASK]')}", flush=True)

    out = os.path.join(args.out_dir, "pieces.json")
    pieces_path = os.path.join(args.out_dir, "pieces.json")
    if os.path.exists(pieces_path):
        shutil.copy(pieces_path, pieces_path + ".bak-79649")
    with open(out, "w") as fh:
        json.dump(pieces, fh, ensure_ascii=False)
    print(f"wrote {out}: {len(pieces)} pieces "
          f"({os.path.getsize(out) / 1e6:.1f}MB)", flush=True)


if __name__ == "__main__":
    main()
