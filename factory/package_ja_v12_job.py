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
    repo = reg.get("ckpt_repo", "kotoshu/gec-ckpt-ja-v12")
    snap = snapshot_download(repo, allow_patterns=["r3s2/final/*", "labels.json"])
    ckpt = os.path.join(snap, "r3s2", "final")
    assert os.path.isfile(os.path.join(ckpt, "model.safetensors")), \
        f"no r3s2/final weights in {repo}"
    print("CKPT:", ckpt, flush=True)
    labels = hf_hub_download(repo, "labels.json")
    # v8-era roberta models: serve-side prefix-space marker (optional;
    # pre-v8 models have none and keep bare-word encoding)
    try:
        marker = hf_hub_download(repo, "prefix_space", repo_type="model")
    except Exception:
        marker = None
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
    subprocess.run([sys.executable, os.path.join(scripts, "prune_export_hf.py"),
                    "--ckpt-dir", ckpt, "--labels", labels,
                    "--corpus", f"/corpora/corpora/{prune_corpus}",
                    "--charsmap", "/code/data/charsmap_mdeberta.json",
                    "--tokenizer", tokenizer,
                    "--out-dir", out] + np, check=True)
    if marker:
        shutil.copy(marker, os.path.join(out, "prefix_space"))

    parity = os.path.join(out, "parity.json")
    subprocess.run([sys.executable, "/app/factory/parity.py",
                    "--pruned-onnx", os.path.join(out, "gec-gector.onnx"),
                    "--full-ckpt", os.path.join(ckpt, "model.safetensors"),
                    "--corpus", f"/corpora/corpora/{prune_corpus}",
                    "--rows", str(a.rows), "--json", parity,
                    "--labels", labels, "--tok-dir", out,
                    "--base-model", tokenizer], check=True)
    gate = json.load(open(parity))["gate"]
    assert gate == "PASS", f"PARITY GATE FAILED"

    for f in os.listdir(out):
        api.upload_file(path_or_fileobj=os.path.join(out, f),
                        path_in_repo=f"ja-v12-r3/{f}", repo_type="dataset",
                        repo_id="kotoshu/gec-artifacts",
                        commit_message=f"{lang} {f}")
        print("uploaded", f, flush=True)
    fs = api.list_repo_files("kotoshu/gec-artifacts", repo_type="dataset")
    for need in ("gec-tagger.int8.onnx", "labels.json", "pieces.json",
                 "charsmap.json", "parity.json"):
        assert f"ja-v12-r3/{need}" in fs, f"VERIFY FAIL: {need}"
    print("SECOND-JOB VERIFY OK — PACKAGE COMPLETE", flush=True)


def glob(snap, stage):
    import glob as g
    return g.glob(f"{snap}/{stage}/final")


if __name__ == "__main__":
    main()
