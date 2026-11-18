"""Checkpoint-fusion packaging for the en roberta line (#232 technique).

Averages gec-ckpt-en-v8c r1s1/latest + r1s2/latest, packages through the
no-prune roberta path (prune_export_hf.py), parity gate, uploads to
kotoshu/gec-artifacts under en-fused/. Exits nonzero on any gate failure.

Usage (inside a job): python3 fuse_package_job.py
"""
from __future__ import annotations
import json
import os
import shutil
import subprocess
import sys
import tempfile

REPO = os.environ.get("FUSE_REPO", "kotoshu/gec-ckpt-en-v8c")
TOKENIZER = os.environ.get("TOKENIZER", "roberta-base")
CORPUS = os.environ.get("PRUNE_CORPUS", "/corpora/base_en_xl.txt")
# roberta-family packages unpruned; mdeberta-family prunes (default keeps
# the en line's behavior; set NO_PRUNE=0 for mdeberta)
NO_PRUNE = os.environ.get("NO_PRUNE", "1") == "1"
OUT_PATH = os.environ.get("OUT_PATH", "en-fused")
# when set: package that directory's r1s2/latest as-is (bucket-vol ckpt
# from a --ckpt-vol training run) instead of hub-fusing two stages
VOL_CKPT = os.environ.get("VOL_CKPT", "")


def main():
    from huggingface_hub import HfApi, hf_hub_download, snapshot_download
    api = HfApi()
    work = tempfile.mkdtemp(prefix="fuse-")
    os.chdir(work)

    if VOL_CKPT:
        stage_dir = os.path.join(VOL_CKPT, "r1s2")
        ckpt = None
        for sub in ("final", "latest"):
            cand = os.path.join(stage_dir, sub)
            if os.path.isfile(os.path.join(cand, "model.safetensors")):
                ckpt = cand
                break
        if ckpt is None:
            # vol runs may push stage-end numbered checkpoints only
            numbered = sorted((d for d in os.listdir(stage_dir)
                               if d.startswith("checkpoint-")),
                              key=lambda p: int(p.rsplit("-", 1)[1]))
            assert numbered, f"no checkpoints under {stage_dir}"
            ckpt = os.path.join(stage_dir, numbered[-1])
        labels = os.path.join(VOL_CKPT, "export/labels.json")
        marker = os.path.join(VOL_CKPT, "export/prefix_space")
        assert os.path.isfile(os.path.join(ckpt, "model.safetensors")), \
            f"no vol checkpoint at {ckpt}"
        print(f"vol-ckpt: {ckpt}", flush=True)
    else:
        s1 = snapshot_download(REPO, allow_patterns=["r1s1/final/*", "r1s1/latest/*"],
                               local_dir=os.path.join(work, "s1"))
        s2 = snapshot_download(REPO, allow_patterns=["r1s2/final/*", "r1s2/latest/*"],
                               local_dir=os.path.join(work, "s2"))
        s1c = os.path.join(s1, "r1s1", "final")
        s2c = os.path.join(s2, "r1s2", "final")
        if not os.path.isfile(os.path.join(s1c, "model.safetensors")):
            s1c = os.path.join(s1, "r1s1", "latest")
        if not os.path.isfile(os.path.join(s2c, "model.safetensors")):
            s2c = os.path.join(s2, "r1s2", "latest")
        shutil.copy(os.path.join(s1c, "config.json"), "config.json")
        labels = hf_hub_download(REPO, "labels.json")
        marker = hf_hub_download(REPO, "prefix_space", repo_type="model")

        from safetensors.torch import load_file, save_file
        sa = load_file(os.path.join(s1c, "model.safetensors"))
        sb = load_file(os.path.join(s2c, "model.safetensors"))
        assert set(sa) == set(sb), "checkpoint key mismatch"
        fused = {}
        for k in sb:
            if k in sa and sa[k].is_floating_point():
                fused[k] = ((sa[k].float() + sb[k].float()) / 2).to(sb[k].dtype)
            else:
                fused[k] = sb[k]
        ckpt = os.path.join(work, "fused-ckpt")
        os.makedirs(ckpt, exist_ok=True)
        save_file(fused, os.path.join(ckpt, "model.safetensors"))
        shutil.copy("config.json", os.path.join(ckpt, "config.json"))
        print("fused: r1s1 + r1s2 0.5/0.5 "
              f"({os.path.basename(os.path.dirname(s1c))}/{os.path.basename(s1c)} "
              f"+ {os.path.basename(os.path.dirname(s2c))}/{os.path.basename(s2c)})",
              flush=True)

    out = os.path.join(work, "out")
    np_args = ["--no-prune"] if NO_PRUNE else []
    subprocess.run([sys.executable, "/app/scripts/prune_export_hf.py",
                    "--ckpt-dir", ckpt, "--labels", labels,
                    "--corpus", CORPUS,
                    "--charsmap", "/code/data/charsmap_mdeberta.json",
                    "--tokenizer", TOKENIZER,
                    "--out-dir", out] + np_args, check=True)
    if os.path.isfile(marker):
        shutil.copy(marker, os.path.join(out, "prefix_space"))

    parity = os.path.join(out, "parity.json")
    subprocess.run([sys.executable, "/app/factory/parity.py",
                    "--pruned-onnx", os.path.join(out, "gec-gector.onnx"),
                    "--full-ckpt", os.path.join(ckpt, "model.safetensors"),
                    "--corpus", CORPUS,
                    "--rows", "60", "--json", parity,
                    "--labels", labels, "--tok-dir", out,
                    "--base-model", TOKENIZER], check=True)
    gate = json.load(open(parity))["gate"]
    assert gate == "PASS", "PARITY GATE FAILED"

    api.create_repo("kotoshu/gec-artifacts", repo_type="dataset", exist_ok=True)
    for f in os.listdir(out):
        api.upload_file(path_or_fileobj=os.path.join(out, f),
                        path_in_repo=f"{OUT_PATH}/{f}", repo_type="dataset",
                        repo_id="kotoshu/gec-artifacts",
                        commit_message=f"{OUT_PATH} {f}")
        print("uploaded", f, flush=True)
    print("FUSE PACKAGE COMPLETE", flush=True)


if __name__ == "__main__":
    main()
