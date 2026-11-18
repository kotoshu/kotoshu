"""Derive REAL substitution confusion counts from the GitHub Typo Corpus
(TODO 151 channel iteration). Pairs appearing in the frozen eval split
(eval/realword/en.github-typo.json) are EXCLUDED — the channel must be
tuned on non-eval data only.

Output: eval/realword/en.typo-confusions.json —
  {"meta": {...}, "sub": {"wa": 12, ...},  # "wrongchar+rightchar": count
   "trans": 1234, "ins": 2233, "del": 3211}
Char keys are the lowercased letters (typo-char then cand-char).
"""
import json
from collections import Counter

EVAL = "/Users/mulgogi/src/kotoshu/kotoshu/eval/realword/en.github-typo.json"
PAIRS = "/Users/mulgogi/src/kotoshu/models-fasttext-onnx/eval/corpora/en.json"
OUT = "/Users/mulgogi/src/kotoshu/kotoshu/eval/realword/en.typo-confusions.json"

eval_pairs = json.load(open(EVAL))["pairs"]
eval_set = {(p["typo"].lower(), p["correction"].lower()) for p in eval_pairs}
eval_typos = {p["typo"].lower() for p in eval_pairs}

data = json.load(open(PAIRS))
pairs = data["pairs"]

sub, trans, ins, dels = Counter(), 0, 0, 0
skipped_eval = skipped_ambiguous = 0
for typo, corr, count in pairs:
    t, c = typo.lower(), corr.lower()
    if t == c:
        continue
    # exclusion: any overlap with the eval split (either direction,
    # either side) keeps the channel clean of test leakage
    if (t, c) in eval_set or (c, t) in eval_set:
        skipped_eval += count
        continue
    if len(t) == len(c):
        diffs = [(a, b) for a, b in zip(t, c) if a != b]
        if len(diffs) == 1:
            w, r = diffs[0]
            if w.isalpha() and r.isalpha():
                sub[w + r] += count
                continue
        if len(diffs) == 2:
            (w1, r1), (w2, r2) = diffs
            if (w1 == r2 and w2 == r1 and diffs[0][0] != diffs[1][0]):
                trans += count
                continue
        skipped_ambiguous += count
        continue
    if len(c) == len(t) + 1:
        ins += count
    elif len(t) == len(c) + 1:
        dels += count
    else:
        skipped_ambiguous += count

out = {
    "meta": {
        "source": data["corpus"],
        "extraction": data["extraction"],
        "derived": "substitution confusion counts (TODO 151); eval-split "
                   "pairs excluded (both directions)",
        "n_unique_pairs": len(pairs),
        "skipped_eval_overlap_pairs": skipped_eval,
        "skipped_ambiguous_pairs": skipped_ambiguous,
        "op_totals": {"substitution": sum(sub.values()),
                      "transposition": trans, "insertion": ins, "deletion": dels},
    },
    "sub": dict(sub.most_common()),
}
json.dump(out, open(OUT, "w"), indent=1)
top = list(out["sub"].items())[:15]
print(f"eval-overlap skipped: {skipped_eval} occurrences")
print(f"sub ops: {sum(sub.values())}, trans: {trans}, ins: {ins}, del: {dels}")
print("top confusion pairs:", top)
print("wrote", OUT)
