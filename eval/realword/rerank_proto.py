"""Offline re-rank prototype: does a real-typo confusion term lift top-1
on the bench slates? (TODO 151 channel iteration — fast signal check.)

Loads bench slates (eval/nonword_bench.rb output), re-ranks each slate:
  score(cand) = (5 - position) + LAMBDA * boost(cand, typo)
where boost = normalized log-count of the (typo_char, cand_char)
substitution pair from the GTC-derived table (single-substitution diffs
only). Reports top-1/3/5 before and after, per class, for a LAMBDA scan.
"""
import json
import math
import sys
from collections import Counter

CONF = "/Users/mulgogi/src/kotoshu/kotoshu/eval/realword/en.typo-confusions.json"


def load_conf():
    d = json.load(open(CONF))
    sub = d["sub"]
    mx = max(sub.values())
    logmx = math.log1p(mx)
    return {k: math.log1p(v) / logmx for k, v in sub.items()}


def boost(conf, typo, cand):
    t, c = typo.lower(), cand.lower()
    if len(t) != len(c):
        return 0.0
    diffs = [(a, b) for a, b in zip(t, c) if a != b]
    if len(diffs) != 1:
        return 0.0
    return conf.get(diffs[0][0] + diffs[0][1], 0.0)


def score(slates, conf, lam):
    tot = Counter(); h1 = Counter(); h3 = Counter(); h5 = Counter()
    for s in slates:
        c = s.get("class", "other") or "other"
        gold = s["correction"].lower()
        t5 = list(s["top5"])
        reranked = sorted(t5,
                          key=lambda w: -((5 - t5.index(w)) +
                                          lam * boost(conf, s["typo"], w)))
        reranked = [w.lower() for w in reranked]
        tot[c] += 1
        if reranked[0] == gold:
            h1[c] += 1
        if gold in reranked[:3]:
            h3[c] += 1
        if gold in reranked[:5]:
            h5[c] += 1
    n = sum(tot.values())
    pct = lambda a, b: 100 * a / b if b else 0
    return pct(sum(h1.values()), n), pct(sum(h3.values()), n), \
        pct(sum(h5.values()), n), {c: pct(h1[c], tot[c]) for c in tot}


def main():
    slates = json.load(open(sys.argv[1]))
    conf = load_conf()
    base = score(slates, conf, 0.0)
    print(f"baseline      top1 {base[0]:.2f} top3 {base[1]:.2f} top5 {base[2]:.2f}")
    for lam in (0.5, 1.0, 2.0, 3.0, 5.0):
        t1, t3, t5, per = score(slates, conf, lam)
        cls = "  ".join(f"{c}={v:.1f}" for c, v in sorted(per.items()))
        print(f"lambda={lam:<4} top1 {t1:.2f} top3 {t3:.2f} top5 {t5:.2f}   {cls}")


if __name__ == "__main__":
    main()
