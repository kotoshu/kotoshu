"""KLF package job — hub-flow packaging for one language (runs IN a job).

Hub checkpoint -> prune (registry corpus) -> fp32 ONNX -> int8 (NaN gate)
-> weight-truth pieces remap -> parity gate -> upload to
kotoshu/gec-artifacts (dataset repo). Exits nonzero on any gate failure.

Usage: python3 package_job.py --lang ru
"""
from __future__ import annotations
import argparse
import json
import os
import shutil
import subprocess
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    ap.add_argument("--rows", type=int, default=60)
    a = ap.parse_args()
    lang = a.lang
    from huggingface_hub import HfApi, hf_hub_download, snapshot_download
    api = HfApi()
    api.create_repo("kotoshu/gec-artifacts", repo_type="dataset", exist_ok=True)
    import yaml
    reg = yaml.safe_load(open(f"/app/factory/registry/{lang}.yaml"))
    repo = reg.get("ckpt_repo", f"kotoshu/gec-ckpt-{lang}")
    vol_dir = os.environ.get("CKPT_DIR", "")
    if vol_dir:
        # bucket-vol lanes (storage law round 7): weights live in the job
        # bucket, not a hub ckpt repo — LABELS env carries labels.json
        ckpt = vol_dir
        assert os.path.isfile(os.path.join(ckpt, "model.safetensors")), \
            f"no weights at CKPT_DIR {ckpt}"
        labels = os.environ["LABELS"]
        marker = None
    else:
        snap = snapshot_download(repo, allow_patterns=[
            "r1s2/final/*", "r1s2/latest/*", "r1s1/final/*", "labels.json"])
        # stage 2 is the final model; stage 1 anchors are only fallback;
        # stage dirs carry {final (banked true-final), latest (periodic),
        # checkpoint-N (legacy numbered)} — final wins, then latest
        cks = (sorted(glob(snap, stage="r1s2"), key=rank) or
               sorted(glob(snap, stage="r1s1"), key=rank))
        assert cks, f"no checkpoints in {repo}"
        ckpt = cks[-1]
        labels = hf_hub_download(repo, "labels.json")
        # v8-era roberta models: serve-side prefix-space marker (optional;
        # pre-v8 models have none and keep bare-word encoding)
        try:
            marker = hf_hub_download(repo, "prefix_space", repo_type="model")
        except Exception:
            marker = None
    print("CKPT:", ckpt, flush=True)
    prune_corpus = reg.get("base", {}).get(
        "prune_corpus", f"base_{lang}.txt")
    print("prune corpus:", prune_corpus, flush=True)

    scripts = "/app/scripts"
    out = "/tmp/out"
    os.makedirs(out, exist_ok=True)
    # en is roberta-family (50k vocab): the pruner's default mdeberta
    # tokenizer (250k) overruns the embedding matrix (2026-10-31 IndexError)
    tokenizer = reg.get("tokenizer", "microsoft/mdeberta-v3-base")
    np = [] if reg.get("prune", True) else ["--no-prune"]
    if reg.get("quantize") is False:
        # deberta law (2026-11-20): quantize_dynamic collapses deberta
        # activations — registries shipping deberta set quantize: false
        # and the fp16-cast export is shipped as gec-tagger.int8.onnx
        np += ["--no-quantize"]
    if reg.get("max_pieces"):
        np += ["--max-pieces", str(reg["max_pieces"])]
    charsmap = f"/code/data/{reg.get('charsmap', 'charsmap_mdeberta.json')}"
    subprocess.run([sys.executable, os.path.join(scripts, "prune_export_hf.py"),
                    "--ckpt-dir", ckpt, "--labels", labels,
                    "--corpus", f"/corpora/{prune_corpus}",
                    "--charsmap", charsmap,
                    "--tokenizer", tokenizer,
                    "--out-dir", out] + np, check=True)
    if marker:
        shutil.copy(marker, os.path.join(out, "prefix_space"))

    parity = os.path.join(out, "parity.json")
    subprocess.run([sys.executable, "/app/factory/parity.py",
                    "--pruned-onnx", os.path.join(out, "gec-gector.onnx"),
                    "--full-ckpt", os.path.join(ckpt, "model.safetensors"),
                    "--corpus", f"/corpora/{prune_corpus}",
                    "--rows", str(a.rows), "--json", parity,
                    "--labels", labels, "--tok-dir", out,
                    "--base-model", tokenizer], check=True)
    gate = json.load(open(parity))["gate"]
    assert gate == "PASS", f"PARITY GATE FAILED"

    for f in os.listdir(out):
        api.upload_file(path_or_fileobj=os.path.join(out, f),
                        path_in_repo=f"{lang}/{f}", repo_type="dataset",
                        repo_id="kotoshu/gec-artifacts",
                        commit_message=f"{lang} {f}")
        print("uploaded", f, flush=True)
    fs = api.list_repo_files("kotoshu/gec-artifacts", repo_type="dataset")
    need = ["gec-tagger.int8.onnx", "labels.json", "parity.json"]
    if reg.get("prune", True):
        # roberta-family (--no-prune) has no sentencepiece pieces table
        need += ["pieces.json"]
    need += ["charsmap.json"]
    for f in need:
        assert f"{lang}/{f}" in fs, f"VERIFY FAIL: {f}"
    print("SECOND-JOB VERIFY OK — PACKAGE COMPLETE", flush=True)


def glob(snap, stage):
    import glob as g
    out = []
    for sub in ("final", "latest"):
        out += g.glob(f"{snap}/{stage}/{sub}")
    return out + g.glob(f"{snap}/{stage}/checkpoint-*")


def rank(p):
    tail = p.rstrip("/").rsplit("/", 1)[-1]
    if tail == "final":
        return (2, 0)
    if tail == "latest":
        return (1, 0)
    return (0, int(tail.rsplit("-", 1)[1]))


if __name__ == "__main__":
    main()
