"""Objective corruption-gold scorer: token-level P/R/F0.5 for a model's
corrections against held-out (corrupted, clean) gold pairs.

This gives EVERY language an objective, reproducible metric — no license
gates, no judge subjectivity. The gold is the corruption pack's own
known ground truth on a held-out slice the teacher never saw.

Usage:
  python3 gold_score.py GOLD.tsv SYSTEM.txt [--json OUT.json]

GOLD.tsv lines: "corrupted\tclean" (tab-separated).
SYSTEM.txt: one corrected sentence per line, same order/count.
"""
import argparse
import difflib
import json


def _norm(line):
    """CJK lines carry no inter-word spaces while decoder output is
    space-joined — compare at CHARACTER level for majority-CJK
    lines (see the join below for why stripping alone is unsafe)."""
    cjk = sum(1 for ch in line
              if "\u4e00" <= ch <= "\u9fff" or "\uac00" <= ch <= "\ud7af"
              or "\u3040" <= ch <= "\u30ff")
    if cjk >= 0.3 * max(1, len(line)):
        # CHARACTER-level tokens: space-stripping alone glues appended
        # junk onto the single CJK token, blinding edit spans and the
        # inflation guard alike.
        return " ".join(line.replace(" ", ""))
    return line


def edits(src_tokens, tgt_tokens):
    """Token spans where src and tgt differ: (is_insert, src_span, tgt_span)."""
    sm = difflib.SequenceMatcher(None, src_tokens, tgt_tokens, autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            out.append((i1, i2, src_tokens[i1:i2], tgt_tokens[j1:j2]))
    return out


def overlap(a, b):
    lo, hi = max(a[0], b[0]), min(a[1], b[1])
    return max(0, hi - lo)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("gold_tsv")
    ap.add_argument("system_txt")
    ap.add_argument("--json", default="")
    a = ap.parse_args()

    gold = [l.rstrip("\n").split("\t") for l in open(a.gold_tsv) if l.strip()]
    system = [l.rstrip("\n") for l in open(a.system_txt)]
    assert len(gold) == len(system), f"line mismatch: {len(gold)} gold vs {len(system)} system"

    tp = fp = fn = 0
    sentences = len(gold)
    untouched_ok = 0
    per_sentence = []
    for (corrupted, clean), corrected in zip(gold, system):
        c2, cl2, co2 = _norm(corrupted), _norm(clean), _norm(corrected)
        gt = edits(c2.split(), cl2.split())
        sysd = edits(c2.split(), co2.split())
        # Pathological-inflation guard: output far longer than its input
        # (append spam) must not score as gold-matching under the coarse
        # single-token normalization CJK lines get.
        if len(co2.split()) > 1.5 * len(c2.split()) + 2:
            fp += len(sysd)
            fn += len(gt)
            per_sentence.append(len(gt))
            continue
        matched = 0
        for s in sysd:
            span = (s[0], s[1])
            slen = span[1] - span[0]
            # A system edit may only match a gold edit of comparable size:
            # a giant delete span overlapping a 1-char gold edit is the
            # mass-deletion signature, not a correction.
            hit = any(overlap(span, (g[0], g[1])) > 0
                      and slen <= 3 * (g[1] - g[0]) + 3 for g in gt)
            if hit:
                matched += 1
            else:
                fp += 1
        fn += max(0, len(gt) - matched)
        tp += matched
        if not gt and not sysd:
            untouched_ok += 1
        per_sentence.append(len(gt))
    precision = tp / (tp + fp) if tp + fp else 1.0
    recall = tp / (tp + fn) if tp + fn else 1.0
    f05 = 1.25 * precision * recall / (0.25 * precision + recall) if (precision + recall) else 0.0
    result = {"sentences": sentences, "gold_edits": tp + fn,
              "precision": round(precision, 4), "recall": round(recall, 4),
              "f0.5": round(f05, 4), "clean_kept": untouched_ok}
    print(json.dumps(result))
    if a.json:
        open(a.json, "w").write(json.dumps(result, indent=1))


if __name__ == "__main__":
    main()
