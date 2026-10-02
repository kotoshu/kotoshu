"""Convert a cLang-8 source-target TSV (tab-separated, tokenized) into
GECToR-labeled jsonl for train_gector_modal.py, applying the same
quality filters as the other corpora: sane length, survivable
alignment. Optionally drops pairs whose source appears in a leak-file
(one source per line, e.g. the W&I dev set).

Usage: python3 scripts/label_clang8.py IN.tsv OUT.jsonl [--leak LEAK.txt]
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gector_prep import extract


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("tsv")
    ap.add_argument("out")
    ap.add_argument("--leak", default=None)
    ap.add_argument("--max-frac-edited", type=float, default=0.5)
    args = ap.parse_args()

    leak = set()
    if args.leak:
        leak = {line.rstrip("\n") for line in open(args.leak)}

    kept = dropped = 0
    with open(args.tsv) as fh, open(args.out, "w") as out:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) != 2:
                dropped += 1
                continue
            source, target = parts
            if source in leak:
                dropped += 1
                continue
            s, t = source.split(), target.split()
            if not (1 <= len(s) <= 80) or not (1 <= len(t) <= 80):
                dropped += 1
                continue
            labels = extract(s, t)
            edited = sum(1 for lbl in labels if lbl != "$KEEP")
            if edited / max(len(s), 1) > args.max_frac_edited:
                dropped += 1
                continue
            out.write(json.dumps({"src_tokens": s, "labels": labels}) + "\n")
            kept += 1
    print(f"kept {kept}, dropped {dropped}")


if __name__ == "__main__":
    main()
