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
    snap = snapshot_download(repo, allow_patterns=["r1s2/*", "r1s1/*"])
    # stage 2 is the final model; stage 1 anchors are only fallback
    cks = sorted(glob(snap, stage="r1s2"), key=lambda p: int(p.rsplit("-", 1)[1])) or \
          sorted(glob(snap, stage="r1s1"), key=lambda p: int(p.rsplit("-", 1)[1]))
    assert cks, f"no checkpoints in {repo}"
    ckpt = cks[-1]
    print("CKPT:", ckpt, flush=True)
    labels = hf_hub_download(repo, "labels.json")
    prune_corpus = reg.get("base", {}).get(
        "prune_corpus", f"base_{lang}.txt")
    print("prune corpus:", prune_corpus, flush=True)

    scripts = "/app/scripts"
    out = "/tmp/out"
    os.makedirs(out, exist_ok=True)
    subprocess.run([sys.executable, os.path.join(scripts, "prune_export_hf.py"),
                    "--ckpt-dir", ckpt, "--labels", labels,
                    "--corpus", f"/corpora/{prune_corpus}",
                    "--charsmap", "/code/data/charsmap_mdeberta.json",
                    "--out-dir", out], check=True)

    parity = os.path.join(out, "parity.json")
    subprocess.run([sys.executable, "/app/factory/parity.py",
                    "--pruned-onnx", os.path.join(out, "gec-gector.onnx"),
                    "--full-ckpt", os.path.join(ckpt, "model.safetensors"),
                    "--corpus", f"/corpora/{prune_corpus}",
                    "--rows", str(a.rows), "--json", parity,
                    "--labels", labels, "--tok-dir", out], check=True)
    gate = json.load(open(parity))["gate"]
    assert gate == "PASS", f"PARITY GATE FAILED"

    for f in os.listdir(out):
        api.upload_file(path_or_fileobj=os.path.join(out, f),
                        path_in_repo=f"{lang}/{f}", repo_type="dataset",
                        repo_id="kotoshu/gec-artifacts",
                        commit_message=f"{lang} {f}")
        print("uploaded", f, flush=True)
    fs = api.list_repo_files("kotoshu/gec-artifacts", repo_type="dataset")
    for need in ("gec-tagger.int8.onnx", "labels.json", "pieces.json",
                 "charsmap.json", "parity.json"):
        assert f"{lang}/{need}" in fs, f"VERIFY FAIL: {need}"
    print("SECOND-JOB VERIFY OK — PACKAGE COMPLETE", flush=True)


def glob(snap, stage):
    import glob as g
    return g.glob(f"{snap}/{stage}/checkpoint-*")


if __name__ == "__main__":
    main()
