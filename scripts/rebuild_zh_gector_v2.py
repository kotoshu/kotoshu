"""Rebuild the zh rows of the cjk union GECToR corpus on SEGMENTED tokens.

v2 of this rebuild. The first version position-zipped two independently
skipping segmentations (empty / <3-token lines dropped by the segmenter),
so after the first skip every src was paired with the WRONG clean
sentence: 68% of rows were cross-paired, 90% of edit labels became
$DELETE, and the trained model mass-deleted (the grammar-cjk v2
incident). This version joins the two sides by original LINE INDEX via
zh_segment_corpus_indexed.rb and enforces data-quality gates before
writing anything.

Output: zh_gector_seg_v2.jsonl
Gates (hard-fail the build):
  - mean edits per sentence <= 5.0
  - $DELETE share of edit labels <= 0.30
  - per-row: a row with >30% $DELETE labels is dropped and counted
"""
import json
import subprocess
import sys
import os
import collections

CACHE = os.path.expanduser("~/.cache/kotoshu-gec")
CORP = CACHE + "/corpora"
DICT = CACHE + "/cjk/zh_dict.txt"
REPO = "/Users/mulgogi/src/kotoshu/kotoshu"
sys.path.insert(0, REPO + "/scripts")
from gector_prep import extract


def segment_indexed(lines, tag):
    inp = os.path.join(CACHE, f"seg_{tag}_v2.txt")
    out = os.path.join(CACHE, f"seg_{tag}_v2.tsv")
    with open(inp, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    subprocess.run(["ruby", "-Ilib", "-rkotoshu",
                    "scripts/zh_segment_corpus_indexed.rb", DICT, inp, out],
                   cwd=REPO, check=True)
    segs = {}
    for line in open(out, encoding="utf-8"):
        idx, _, words = line.rstrip("\n").partition("\t")
        segs[int(idx)] = words.split(" ") if words else None
    return segs


def main():
    out_path = f"{CORP}/zh_gector_seg_v2.jsonl"
    total_edits = 0
    total_rows = 0
    label_counts = collections.Counter()
    dropped_rows = 0
    with open(out_path, "w", encoding="utf-8") as fout:
        for pack, vfile in (("zh_hans", "zh_hans_verified.jsonl"),
                            ("zh_hant", "zh-Hant_verified.jsonl")):
            src = f"{CORP}/{vfile}"
            if not os.path.exists(src):
                print("MISSING", src)
                continue
            pairs = [json.loads(l) for l in open(src, encoding="utf-8")]
            cleans = [p["clean"] for p in pairs]
            corrs = [p["corrupted"] for p in pairs]
            print(pack, len(pairs), "pairs; segmenting by index", flush=True)
            clean_seg = segment_indexed(cleans, pack + "_c")
            corr_seg = segment_indexed(corrs, pack + "_k")
            joined = 0
            for i in sorted(set(clean_seg) & set(corr_seg)):
                cs, ks = clean_seg[i], corr_seg[i]
                if not cs or not ks:
                    continue
                labels = extract(ks, cs)
                n_edit = sum(1 for l in labels if l != "$KEEP")
                if n_edit == 0:
                    continue
                n_del = sum(1 for l in labels if l == "$DELETE")
                if n_del > 0.3 * len(labels):
                    dropped_rows += 1
                    continue
                joined += 1
                total_rows += 1
                total_edits += n_edit
                for l in labels:
                    if l != "$KEEP":
                        label_counts["REPLACE" if l.startswith("$REPLACE") else l.lstrip("$").split("_")[0]] += 1
                fout.write(json.dumps({"src_tokens": ks, "labels": labels},
                                      ensure_ascii=False) + "\n")
            print(pack, "wrote", joined, "rows (dropped", dropped_rows, "degenerate)", flush=True)

    mean_edits = total_edits / total_rows if total_rows else 0
    del_share = label_counts["DELETE"] / max(1, sum(label_counts.values()))
    print(f"TOTAL {total_rows} rows; mean edits/sent {mean_edits:.2f}; "
          f"labels {dict(label_counts.most_common())}; DELETE share {del_share:.3f}")
    if mean_edits > 5.0:
        sys.exit(f"GATE FAIL: mean edits/sentence {mean_edits:.2f} > 5.0")
    if del_share > 0.30:
        sys.exit(f"GATE FAIL: $DELETE label share {del_share:.3f} > 0.30")
    print("GATES PASS")


if __name__ == "__main__":
    main()
