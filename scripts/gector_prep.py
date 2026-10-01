"""GECToR-style label extraction from aligned (source, target) token
pairs (Omelianchuk et al. 2020): $KEEP, $REPLACE_x, $APPEND_x,
$DELETE, $TRANSFORM_*, $MERGE."""
import json, sys, re
from difflib import SequenceMatcher

def verb_form(src, tgt):
    # same-lemma verb form changes -> closed transform labels
    table = {
        ("s", ""): "$TRANSFORM_VERB_S", ("es", ""): "$TRANSFORM_VERB_S",
        ("ed", ""): "$TRANSFORM_VERB_ED", ("ied", "y"): "$TRANSFORM_VERB_ED",
        ("ing", ""): "$TRANSFORM_VERB_ING", ("ing", "e"): "$TRANSFORM_VERB_ING",
    }
    a, b = src.lower(), tgt.lower()
    if a == b:
        return None
    for (asuf, bsuf), label in table.items():
        if a.endswith(asuf) and b.endswith(bsuf) and a[: -len(asuf)] == b[: -len(bsuf)]:
            return label
    return None

def case_transform(src, tgt):
    if src.lower() == tgt.lower() and src != tgt:
        if tgt[0].isupper():
            return "$TRANSFORM_CASE_CAPITALIZE"
        return "$TRANSFORM_CASE_LOWER"
    return None

def extract(src_tokens, tgt_tokens):
    labels = ["$KEEP"] * len(src_tokens)
    sm = SequenceMatcher(None, src_tokens, tgt_tokens, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        src_span = src_tokens[i1:i2]
        tgt_span = tgt_tokens[j1:j2]
        if len(src_span) == 1 and len(tgt_span) == 1:
            s, t = src_span[0], tgt_span[0]
            if s.isalpha() and t.isalpha():
                vf = verb_form(s, t)
                if vf:
                    labels[i1] = vf
                    continue
                ct = case_transform(s, t)
                if ct:
                    labels[i1] = ct
                    continue
            labels[i1] = f"$REPLACE_{t}"
        elif len(src_span) == 0 and len(tgt_span) >= 1:
            # insertion: append to the previous token (or prepend)
            idx = i1 - 1 if i1 > 0 else 0
            appends = " ".join(tgt_span)
            labels[idx] = (f"$APPEND_{appends}" if labels[idx] == "$KEEP" else labels[idx])
            if i1 == 0:
                labels[0] = f"$APPEND_{appends}"
        elif len(tgt_span) == 0:
            for k in range(i1, i2):
                labels[k] = "$DELETE"
        elif len(src_span) == 2 and len(tgt_span) == 1:
            labels[i1] = "$MERGE_" + tgt_span[0]
            labels[i1 + 1] = "$DELETE"
        else:
            # many-to-many: replace first, delete rest
            labels[i1] = f"$REPLACE_{' '.join(tgt_span)}"
            for k in range(i1 + 1, i2):
                labels[k] = "$DELETE"
    return labels

def main(pairs_jsonl, out_jsonl):
    n = 0
    with open(pairs_jsonl) as fin, open(out_jsonl, "w") as fout:
        for line in fin:
            obj = json.loads(line)
            src = obj.get("corrupted", obj.get("src"))
            tgt = obj.get("clean", obj.get("tgt"))
            if src is None or tgt is None:
                continue
            src_tokens = src.split()
            tgt_tokens = tgt.split()
            if not src_tokens or not tgt_tokens or len(src_tokens) > 90:
                continue
            labels = extract(src_tokens, tgt_tokens)
            fout.write(json.dumps({"src_tokens": src_tokens, "labels": labels}) + "\n")
            n += 1
    print(f"wrote {n} labeled sentences to {out_jsonl}")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
