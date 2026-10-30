"""Build ja v5 gector rows from the ds4 teacher state.

Takes teacher/ja_v2_ds/ds_out.jsonl (state rows: clean/corrupted/status/
output), dedupes by the corrupted key (refires re-append state), keeps
exact + near-length-variant rows the way the factory verify gate does,
runs gector_prep, enforces the label-density gate, and appends the rows
to the cjk v5 union.
"""
import json
import os
import sys
import collections

CACHE = os.path.expanduser("~/.cache/kotoshu-gec")
CORP = CACHE + "/corpora"
STATE = CACHE + "/ja_v2_ds_state.jsonl"
sys.path.insert(0, "/Users/mulgogi/src/kotoshu/kotoshu/scripts")
from gector_prep import main as prep
sys.path.insert(0, "/Users/mulgogi/src/kotoshu/kotoshu/factory")
from run import _label_density_gate


def main():
    from huggingface_hub import hf_hub_download
    path = hf_hub_download("kotoshu/gec-training-private",
                           "teacher/ja_v2_ds/ds_out.jsonl", repo_type="dataset",
                           local_dir=CACHE + "/ja_v5_verify")
    rows = {}
    for line in open(path, encoding="utf-8"):
        d = json.loads(line)
        rows.setdefault(d["corrupted"], d)
    exact = sum(1 for d in rows.values() if d["status"] == "exact")
    kept = []
    for d in rows.values():
        if d["status"] == "exact":
            kept.append(d)
            continue
        dc = len(d["clean"].split())
        dt = len(d["output"].split())
        if abs(dc - dt) <= 2:
            kept.append(d)
    rate = exact / len(rows) if rows else 0
    print(f"state rows {len(rows)} (deduped), exact {exact} ({rate:.1%}), kept {len(kept)}")
    if rate < 0.30:
        print("WARNING: exact-restore rate below the 30% verify gate — inspect before training")

    pairs = f"{CORP}/ja_v5_pairs.jsonl"
    with open(pairs, "w", encoding="utf-8") as f:
        for d in kept:
            f.write(json.dumps({"corrupted": d["corrupted"], "clean": d["clean"]},
                               ensure_ascii=False) + "\n")
    gector = f"{CORP}/ja_v5_gector.jsonl"
    prep(pairs, gector)
    _label_density_gate(gector)

    union = f"{CORP}/cjk_gector_v5.jsonl"
    n0 = sum(1 for _ in open(union))
    with open(union, "a", encoding="utf-8") as f:
        for line in open(gector, encoding="utf-8"):
            f.write(line)
    n1 = sum(1 for _ in open(union))
    print(f"union {n0} -> {n1} rows")

    from huggingface_hub import HfApi
    api = HfApi()
    api.upload_file(path_or_fileobj=gector, path_in_repo="corpora/ja_v5_gector.jsonl",
                    repo_id="kotoshu/gec-training-private", repo_type="dataset",
                    commit_message="ja v5 gector (ds4 verified, density-gated)")
    print("UPLOADED ja_v5_gector.jsonl")


if __name__ == "__main__":
    main()
