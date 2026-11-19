"""gector_prep + density gate for wave-2 packs.
Usage: python3 wave2_gector.py el uk tr sr
"""
import collections
import json
import sys

sys.path.insert(0, "/Users/mulgogi/src/kotoshu/kotoshu/scripts")
from gector_prep import main as prep

CORP = "/Users/mulgogi/.cache/kotoshu-gec/corpora"

for lang in sys.argv[1:]:
    pairs = f"{CORP}/{lang}_pack/{lang}_v1_pairs.jsonl"
    gector = f"{CORP}/{lang}_gector.jsonl"
    prep(pairs, gector)
    rows = edits = 0
    labels = collections.Counter()
    for line in open(gector, encoding="utf-8"):
        d = json.loads(line)
        rows += 1
        for lab in d["labels"]:
            if lab == "$KEEP":
                continue
            edits += 1
            labels["REPLACE" if lab.startswith("$REPLACE")
                   else lab.lstrip("$").split("_")[0]] += 1
    mean_edits = edits / rows if rows else 0.0
    del_share = labels["DELETE"] / max(1, sum(labels.values()))
    status = "PASS" if mean_edits <= 5.0 and del_share <= 0.30 else "FAIL"
    print(f"{lang}: {rows} rows, {mean_edits:.2f} edits/sent, "
          f"DELETE {del_share:.3f} -> {status}")
