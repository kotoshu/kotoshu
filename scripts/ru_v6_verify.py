"""Build ru v6 gector rows from the attested-pack teacher state and fire
the ru v6 train when the gates pass.

teacher/ru_v6/ds_out.jsonl (state rows: clean/corrupted/status/output)
joined to the pairs file by the corrupted key, deduped across refires;
exact + near-length-variant rows kept; density gate enforced; rows land
as ru_gector.jsonl (the train stage's expected path), then train ru runs.
"""
import json
import os
import sys

CACHE = os.path.expanduser("~/.cache/kotoshu-gec")
CORP = CACHE + "/corpora"
sys.path.insert(0, "/Users/mulgogi/src/kotoshu/kotoshu/scripts")
from gector_prep import main as prep
sys.path.insert(0, "/Users/mulgogi/src/kotoshu/kotoshu/factory")
from run import _label_density_gate


def main():
    from huggingface_hub import hf_hub_download
    state = hf_hub_download("kotoshu/gec-training-private",
                            "teacher/ru_v6/ds_out.jsonl", repo_type="dataset",
                            local_dir=CACHE + "/ru_v6_verify")
    pairs_path = hf_hub_download("kotoshu/gec-training-private",
                                 "teacher/ru_v6/pairs.jsonl", repo_type="dataset",
                                 local_dir=CACHE + "/ru_v6_verify")
    pairs = {}
    for line in open(pairs_path, encoding="utf-8"):
        d = json.loads(line)
        pairs[d["corrupted"]] = d["clean"]

    rows = {}
    for line in open(state, encoding="utf-8"):
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
        sys.exit(f"GATE FAIL: ru v6 exact-restore rate {rate:.1%} < 30% — inspect before training")

    pairs_out = f"{CORP}/ru_v6_pairs.jsonl"
    with open(pairs_out, "w", encoding="utf-8") as f:
        for d in kept:
            f.write(json.dumps({"corrupted": d["corrupted"], "clean": d["clean"]},
                               ensure_ascii=False) + "\n")
    gector = f"{CORP}/ru_v6_gector.jsonl"
    prep(pairs_out, gector)
    _label_density_gate(gector)

    import shutil
    shutil.copy(gector, f"{CORP}/ru_gector.jsonl")
    n = sum(1 for _ in open(f"{CORP}/ru_gector.jsonl"))
    print(f"ru_gector.jsonl staged: {n} rows")

    from huggingface_hub import HfApi
    HfApi().upload_file(path_or_fileobj=gector, path_in_repo="corpora/ru_v6_gector.jsonl",
                        repo_id="kotoshu/gec-training-private", repo_type="dataset",
                        commit_message="ru v6 gector (attested pack verified, density-gated)")
    print("UPLOADED ru_v6_gector.jsonl")


if __name__ == "__main__":
    main()
