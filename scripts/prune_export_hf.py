"""Prune + export + quantize + tokenizer-remap for a trained mdeberta
GECToR checkpoint. Runs in an HF cpu job against bucket/dataset mounts
(no hub writes — the org quota wall, 2026-10-12).

Pipeline: keep-set from corpus -> prune embeddings -> fp32 ONNX ->
full QInt8 -> weight-truth pieces.json remap -> labels + charsmap.
quantize_dynamic doubles as the NaN gate ("scale issue" = diverged ckpt).

Usage (inside a job):
  python3 prune_export_hf.py \
    --ckpt-dir /ckvol/gec/fr-v1/r1s2/latest \
    --labels /ckvol/gec/fr-v1/export/labels.json \
    --corpus /data/corpora/base_fr.txt \
    --charsmap /code/data/charsmap_mdeberta.json \
    --out-dir /ckvol/gec/fr-v1/export-pruned
"""
from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys


def prune_and_export(ckpt_dir, corpus_path, charsmap_path, out_dir,
                     tokenizer_name="microsoft/mdeberta-v3-base",
                     labels_src=None):
    import torch
    from onnxruntime.quantization import QuantType, quantize_dynamic
    from transformers import AutoModelForTokenClassification, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(tokenizer_name)
    vocab_size = tok.vocab_size
    keep = set(range(tok.num_special_tokens_to_add()))
    keep |= set(tok.all_special_ids)
    with open(corpus_path) as fh:
        for line in fh:
            if line.strip():
                keep |= set(tok(line, add_special_tokens=True)["input_ids"])
    for i, t in {i: t for t, i in tok.get_vocab().items()}.items():
        if t.startswith("<0x") or t in ("[UNK]", "<unk>", "<pad>"):
            keep.add(i)
    keep_ids = sorted(keep & set(range(vocab_size)))
    added = sorted(i for i in tok.all_special_ids if i >= vocab_size)
    print(f"corpus keep: {len(keep_ids)} base + {len(added)} added", flush=True)

    model = AutoModelForTokenClassification.from_pretrained(ckpt_dir)
    emb = model.get_input_embeddings().weight.data
    new_emb = emb[torch.tensor(keep_ids + added)].clone()
    model.resize_token_embeddings(len(keep_ids) + len(added))
    with torch.no_grad():
        model.get_input_embeddings().weight.copy_(new_emb)
    model.eval()
    print(f"pruned: {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M params",
          flush=True)

    os.makedirs("exp", exist_ok=True)
    onnx_path = "exp/gec-gector.onnx"
    torch.onnx.export(
        model,
        (torch.ones(1, 32, dtype=torch.long), torch.ones(1, 32, dtype=torch.long)),
        onnx_path, input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={"input_ids": {0: "batch", 1: "seq"},
                      "attention_mask": {0: "batch", 1: "seq"},
                      "logits": {0: "batch", 1: "seq"}},
        opset_version=14, dynamo=False)

    os.makedirs(out_dir, exist_ok=True)
    tok.save_pretrained(out_dir)   # full tokenizer: encode then remap ids
    with open(os.path.join(out_dir, "keep_ids.json"), "w") as fh:
        json.dump(keep_ids + added, fh)
    int8 = os.path.join(out_dir, "gec-tagger.int8.onnx")
    quantize_dynamic(onnx_path, int8, weight_type=QuantType.QInt8)
    print(f"int8: {os.path.getsize(int8) / (1024 * 1024):.1f}MB", flush=True)
    # STORAGE/PLATFORM LAW (2026-10-29): the ruby-gem x86 runtime
    # mis-executes DynamicQuantizeLinear/MatMulInteger kernels of these
    # graphs (flat logits). quantize_dynamic stays as the NaN gate; the
    # SHIPPED file is the float dequantization of it — sound ops in
    # every ORT build, same loader filename.
    subprocess.run([sys.executable,
                    os.path.join(scripts, "dequantize_int8_onnx.py"),
                    int8, int8 + ".fq"], check=True)
    os.replace(int8 + ".fq", int8)
    print(f"fp32-fied: {os.path.getsize(int8) / (1024 * 1024):.1f}MB", flush=True)
    shutil.copy(onnx_path, os.path.join(out_dir, "gec-gector.onnx"))

    scripts = os.path.dirname(os.path.abspath(__file__))
    subprocess.run([sys.executable,
                    os.path.join(scripts, "rebuild_pruned_pieces.py"),
                    "--onnx", onnx_path,
                    "--full-ckpt", os.path.join(ckpt_dir, "model.safetensors"),
                    "--tokenizer", tokenizer_name,
                    "--out-dir", out_dir], check=True)
    if labels_src:
        shutil.copy(labels_src, os.path.join(out_dir, "labels.json"))
    if charsmap_path and os.path.exists(charsmap_path):
        shutil.copy(charsmap_path, os.path.join(out_dir, "charsmap.json"))
    print("PRUNE EXPORT COMPLETE", flush=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ckpt-dir", required=True)
    ap.add_argument("--labels", required=True)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--charsmap", required=True)
    ap.add_argument("--out-dir", required=True)
    ap.add_argument("--tokenizer", default="microsoft/mdeberta-v3-base")
    args = ap.parse_args()
    prune_and_export(ckpt_dir=args.ckpt_dir, corpus_path=args.corpus,
                     charsmap_path=args.charsmap, out_dir=args.out_dir,
                     tokenizer_name=args.tokenizer, labels_src=args.labels)


if __name__ == "__main__":
    main()
