"""Per-label threshold tuning over a confidence dump (GECToR's recipe).

Reads the dump from scripts/grammar_conf_dump.rb ({words, preds:[{i,
label, conf}]}) plus gold (src, tgt) pairs, extracts gold labels with
the SAME alignment as training (gector_prep.extract), then greedily
tunes one confidence threshold per label to maximize token-level
F0.5 of non-KEEP predictions.

Usage: python3 scripts/tune_thresholds.py CONFDUMP.jsonl PAIRS.jsonl OUT.json
"""
import json, sys
from collections import Counter, defaultdict

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from gector_prep import extract

BETA = 0.5


def score(preds_by_sent, gold_by_sent, thresholds):
    tp = fp = fn = 0
    for si, gold in enumerate(gold_by_sent):
        preds = preds_by_sent[si]
        for p in preds:
            if p["conf"] < thresholds.get(p["label"], 0.0):
                continue
            if p["i"] < len(gold) and gold[p["i"]] == p["label"]:
                tp += 1
            else:
                fp += 1
        for i, g in enumerate(gold):
            if g == "$KEEP":
                continue
            if not any(p["i"] == i and p["label"] == g
                       and p["conf"] >= thresholds.get(p["label"], 0.0)
                       for p in preds):
                fn += 1
    prec = tp / (tp + fp) if tp + fp else 0.0
    rec = tp / (tp + fn) if tp + fn else 0.0
    f = (1 + BETA * BETA) * prec * rec / (BETA * BETA * prec + rec) \
        if prec + rec else 0.0
    return prec, rec, f


def main(dump_path, pairs_path, out_path):
    preds_by_sent, gold_by_sent = [], []
    with open(dump_path) as df, open(pairs_path) as pf:
        for dline, pline in zip(df, pf):
            d = json.loads(dline)
            p = json.loads(pline)
            gold = extract(d["words"], p["tgt"].split())
            preds_by_sent.append(d["preds"])
            gold_by_sent.append(gold)

    label_counts = Counter(p["label"] for preds in preds_by_sent for p in preds)
    thresholds = {}
    base = score(preds_by_sent, gold_by_sent, thresholds)
    print(f"baseline tau=0 everywhere: P {base[0]:.4f} R {base[1]:.4f} F0.5 {base[2]:.4f}")

    # Greedy: tune the frequent labels against everything else fixed.
    candidates = [0.0, 0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.7]
    best_f = base[2]
    for label, _count in label_counts.most_common(60):
        local_best = thresholds.get(label, 0.0)
        for tau in candidates:
            if tau == thresholds.get(label, 0.0):
                continue
            thresholds[label] = tau
            f = score(preds_by_sent, gold_by_sent, thresholds)[2]
            if f > best_f + 1e-6:
                best_f = f
                local_best = tau
        thresholds[label] = local_best

    final = score(preds_by_sent, gold_by_sent, thresholds)
    print(f"tuned: P {final[0]:.4f} R {final[1]:.4f} F0.5 {final[2]:.4f}")
    tuned = {l: t for l, t in thresholds.items() if t > 0}
    print(f"labels with tau>0: {len(tuned)}")
    json.dump({"thresholds": tuned,
               "dev_token_f05": {"baseline": base[2], "tuned": final[2]}},
              open(out_path, "w"), indent=1)
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
