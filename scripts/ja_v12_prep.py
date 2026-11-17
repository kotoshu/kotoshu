"""Build the ja-v11 MIX corpus: ja_v3 pack gold + ja_v3 teacher exact rows.

ja teacher pass is COMPLETE (70,995/71,812 processed, 11,954 exact —
16.8%). Mix = pack (71,812) + teacher exact (11,954) = 83,766 rows.
Train with the ru-winning 3-round schedule (ko-v11's 1-round mix lost;
ru's 3-round mix won — schedule is the difference).

Usage: python3 ja_v11_prep.py [--no-upload]
"""
import argparse
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gector_prep import main as prep
from huggingface_hub import HfApi, hf_hub_download

HOLD = os.path.expanduser("~/.cache/kotoshu-gec/jadata")
STATE = "corpora/ja_v3_reseg_exact.jsonl"
PACK = "corpora/ja_v3_reseg_pairs.jsonl"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-upload", action="store_true")
    a = ap.parse_args()
    os.makedirs(HOLD, exist_ok=True)

    state = hf_hub_download("kotoshu/gec-training-private", STATE,
                            repo_type="dataset")
    backup = os.path.join(HOLD, "ja_v3_ds_out.jsonl")
    if not os.path.exists(backup):
        shutil.copy(state, backup)
        print(f"state backed up -> {backup}")

    # the reseg job wrote PRE-FILTERED exact rows (corrupted/clean/cls, no
    # status field) — use the file directly
    verified = state
    n = sum(1 for l in open(state) if l.strip())
    print(f"{n} exact rows (pre-filtered) -> {verified}")
    if n == 0:
        raise SystemExit("no exact rows — state incomplete? aborting mix build")
    teacher_g = prep(verified, os.path.join(HOLD, "ja_v3_reseg_teacher_gector.jsonl")) \
        or os.path.join(HOLD, "ja_v3_reseg_teacher_gector.jsonl")

    pack_path = hf_hub_download("kotoshu/gec-training-private", PACK,
                                repo_type="dataset")
    pack_g = os.path.join(HOLD, "ja_v3_reseg_pack_gector.jsonl")
    pairs = os.path.join(HOLD, "ja_v3_reseg_pairs_flat.jsonl")
    with open(pairs, "w") as f:
        for l in open(pack_path):
            if not l.strip():
                continue
            r = json.loads(l)
            f.write(json.dumps({"corrupted": r["corrupted"],
                                "clean": r["clean"],
                                "cls": r.get("class")},
                               ensure_ascii=False) + "\n")
    pack_g = prep(pairs, pack_g) or pack_g

    mix = os.path.join(HOLD, "ja_v12_gector.jsonl")
    total = 0
    with open(mix, "w") as out:
        for src in (pack_g, teacher_g):
            for l in open(src):
                if l.strip():
                    out.write(l)
                    total += 1
    print(f"ja_v12 mix: {total} rows (pack + teacher {n}) -> {mix}")

    if not a.no_upload:
        HfApi().upload_file(path_or_fileobj=mix,
                            path_in_repo="corpora/ja_v12_gector.jsonl",
                            repo_type="dataset",
                            repo_id="kotoshu/gec-training-private",
                            commit_message="ja_v12 mix corpus (pack + ja_v3 teacher exact)")
        print("uploaded corpora/ja_v12_gector.jsonl")


if __name__ == "__main__":
    main()
