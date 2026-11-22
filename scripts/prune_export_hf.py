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
                     labels_src=None, prune=True, no_quantize=False,
                     max_pieces=None):
    import torch
    from onnxruntime.quantization import QuantType, quantize_dynamic
    from transformers import AutoModelForTokenClassification, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(tokenizer_name)
    if prune:
        vocab_size = tok.vocab_size
        from collections import Counter
        keep = set(range(tok.num_special_tokens_to_add()))
        keep |= set(tok.all_special_ids)
        byte_and_unk = {i for i, t in tok.get_vocab().items()
                        if t.startswith("<0x") or t in ("[UNK]", "<unk>", "<pad>")}
        counts = Counter()
        with open(corpus_path) as fh:
            for line in fh:
                if line.strip():
                    counts.update(tok(line, add_special_tokens=True)["input_ids"])
        keep |= set(counts)
        keep |= byte_and_unk
        if max_pieces is not None and len(keep) > max_pieces:
            # frequency cap: keep specials/byte-tokens + the max_pieces most
            # frequent corpus pieces (embedding size is the fp16 ship-size
            # driver; en's corpus-keep left 110k pieces = 350MB, over the
            # 250MB ceiling)
            top = {i for i, _ in counts.most_common(max_pieces)}
            keep = ((keep - set(counts)) | byte_and_unk) | top
        keep_ids = sorted(keep & set(range(vocab_size)))
        added = sorted(i for i in tok.all_special_ids if i >= vocab_size)
        print(f"corpus keep: {len(keep_ids)} base + {len(added)} added", flush=True)

        model = AutoModelForTokenClassification.from_pretrained(ckpt_dir)
        emb = model.get_input_embeddings().weight.data
        new_emb = emb[torch.tensor(keep_ids + added)].clone()
        model.resize_token_embeddings(len(keep_ids) + len(added))
        with torch.no_grad():
            model.get_input_embeddings().weight.copy_(new_emb)
    else:
        # roberta-family: ByteBpe serves the FULL vocab — embedding pruning
        # would desync ids from the tokenizer (and there is no spm.model to
        # rebuild pieces from). roberta-base int8 ~130MB, under budget.
        keep_ids = added = []
        model = AutoModelForTokenClassification.from_pretrained(ckpt_dir)
    model.eval()
    print(f"export: {sum(p.numel() for p in model.parameters()) / 1e6:.1f}M params",
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

    scripts = os.path.dirname(os.path.abspath(__file__))
    os.makedirs(out_dir, exist_ok=True)
    tok.save_pretrained(out_dir)   # full tokenizer: encode then remap ids
    if prune:
        with open(os.path.join(out_dir, "keep_ids.json"), "w") as fh:
            json.dump(keep_ids + added, fh)
    if no_quantize:
        # deberta law (2026-11-20): quantize_dynamic collapses deberta
        # activations — ship the fp16-cast export instead (fp16 weight
        # storage + Cast-to-fp32 nodes, sound ops on arm64 and x86)
        fp16 = os.path.join(out_dir, "gec-tagger.fp16.onnx")
        subprocess.run([sys.executable,
                        os.path.join(scripts, "cast_fp16_onnx.py"),
                        onnx_path, fp16], check=True)
        shutil.copy(fp16, os.path.join(out_dir, "gec-tagger.int8.onnx"))
        print(f"fp16 (shipped as gec-tagger.int8.onnx): "
              f"{os.path.getsize(fp16) / (1024 * 1024):.1f}MB", flush=True)
    else:
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

    if prune:
        subprocess.run([sys.executable,
                        os.path.join(scripts, "rebuild_pruned_pieces.py"),
                        "--onnx", onnx_path,
                        "--full-ckpt", os.path.join(ckpt_dir, "model.safetensors"),
                        "--tokenizer", tokenizer_name,
                        "--out-dir", out_dir], check=True)
    else:
        # ByteBpe layout: full tokenizer files serve directly
        vfn = getattr(tok, "vocab_files_names", {}) or {}
        for canon, key in (("vocab.json", "vocab_file"), ("merges.txt", "merges_file")):
            src = vfn.get(key)
            if src and os.path.exists(src):
                shutil.copy(src, os.path.join(out_dir, canon))
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
    ap.add_argument("--no-prune", action="store_true")
    ap.add_argument("--no-quantize", action="store_true",
                    help="deberta: ship the fp16-cast export instead of "
                         "quantized int8 (quantize_dynamic collapses "
                         "deberta activations)")
    ap.add_argument("--max-pieces", type=int, default=None,
                    help="frequency-cap the keep-set at this many pieces "
                         "(size lever: embedding bytes dominate fp16 ships)")
    args = ap.parse_args()
    prune_and_export(ckpt_dir=args.ckpt_dir, corpus_path=args.corpus,
                     charsmap_path=args.charsmap, out_dir=args.out_dir,
                     tokenizer_name=args.tokenizer, labels_src=args.labels,
                     prune=not args.no_prune, no_quantize=args.no_quantize,
                     max_pieces=args.max_pieces)


if __name__ == "__main__":
    main()
