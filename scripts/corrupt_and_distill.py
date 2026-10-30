"""Typed corruption generator for teacher distillation (Phase 2).

Takes clean sentences and injects grammatical errors in the classes
our error analysis flagged as recall-starved (ArtOrDet, Prep, Nn,
SVA, Wci), producing (corrupted, clean) pairs with known edit
positions — the teacher then corrects the corrupted text and we keep
pairs where the teacher's fix confirms the known ground truth.

Usage:
  python3 scripts/corrupt_and_distill.py corrupt CLEAN.txt OUT.jsonl [--rate 0.8]
  python3 scripts/corrupt_and_distill.py verify CORRUPTED.jsonl TEACHER.txt OUT.jsonl
"""
import argparse
import json
import random
import re
import sys

random.seed(20261003)

PREP_SETS = [
    {"in", "on", "at"},
    {"for", "to"},
    {"of", "for"},
    {"with", "by"},
    {"from", "of"},
    {"about", "on"},
    {"into", "in"},
    {"over", "above"},
    {"under", "below"},
]

CONFUSION = {
    "their": "there", "there": "their",
    "lose": "loose", "loose": "lose",
    "effect": "affect", "affect": "effect",
    "then": "than", "than": "then",
    "accept": "except", "except": "accept",
    "quiet": "quite",
    "advice": "advise",
    "principal": "principle", "principle": "principal",
    "beside": "besides", "besides": "beside",
}

BE_VERB = {"is": "are", "are": "is", "was": "were", "were": "was", "has": "have", "have": "has"}

# frequent unambiguous nouns for number corruption
NOUNS = set("""dog cat car book house day man woman child people year time work
word way thing life world hand part place case week company system program
question government number point home water room mother father area money
story fact month lot right study book eye job word business issue side kind
head house service friend father power hour game line end member law car
city community president team minute idea kid body information back parent
face others level office door health person art war history party result
change morning reason research girl guy moment air teacher force education""".split())

SINGULAR_SUBJ = {"he", "she", "it", "this", "that", "everyone", "somebody", "nobody"}

# never inflect function words when they follow a singular subject
FUNCTION_WORDS = {
    "and", "or", "but", "the", "a", "an", "of", "to", "in", "on", "at", "for",
    "with", "by", "from", "is", "are", "was", "were", "has", "have", "had",
    "will", "would", "can", "could", "should", "not", "no", "also", "then",
}


def tokens(sentence: str) -> list[str]:
    return sentence.split()


def apply_one(corrupted: list[str], i: int, cls: str) -> bool:
    w = corrupted[i]
    lw = w.lower()
    if cls == "ArtOrDet":
        if lw in {"a", "an", "the"}:
            if lw == "a" and i + 1 < len(corrupted) and re.match(r"[aeiou]", corrupted[i + 1][0].lower() if corrupted[i + 1] else ""):
                corrupted[i] = "an" if w[0].islower() else "An"
                return True
            if lw == "the" and i + 1 < len(corrupted):
                # drop the determiner
                del corrupted[i]
                return True
            if lw in {"an", "the"}:
                corrupted[i] = "a" if w[0].islower() else "A"
                return True
        return False
    if cls == "Prep":
        for s in PREP_SETS:
            if lw in s:
                others = sorted(s - {lw})
                nw = random.choice(others)
                corrupted[i] = nw if w[0].islower() else nw.capitalize()
                return True
        return False
    if cls == "Nn":
        if lw in NOUNS:
            if lw.endswith("s") and len(lw) > 3:
                corrupted[i] = lw[:-1]
                return True
            if not lw.endswith("s"):
                corrupted[i] = lw + "s"
                return True
        return False
    if cls == "SVA":
        if lw in BE_VERB:
            nw = BE_VERB[lw]
            corrupted[i] = nw if w[0].islower() else nw.capitalize()
            return True
        if (i > 0 and corrupted[i - 1].lower() in SINGULAR_SUBJ and lw.isalpha()
                and not lw.endswith("s") and lw not in FUNCTION_WORDS):
            corrupted[i] = lw + "s"
            return True
        return False
    if cls == "Wci":
        if lw in CONFUSION:
            nw = CONFUSION[lw]
            corrupted[i] = nw if w[0].islower() else nw.capitalize()
            return True
        return False
    return False


def corrupt_sentence(sentence: str, classes: list[str]) -> dict | None:
    tok = tokens(sentence)
    if not (4 <= len(tok) <= 60):
        return None
    # skip base sentences that already look corrupted (immediate repeats)
    if any(tok[i].lower() == tok[i + 1].lower() for i in range(len(tok) - 1)):
        return None
    cls = random.choice(classes)
    idx = list(range(len(tok)))
    random.shuffle(idx)
    for i in idx:
        work = tok[:]
        if apply_one(work, i, cls):
            if work != tok:
                return {"clean": sentence, "corrupted": " ".join(work), "cls": cls}
    return None


def cmd_corrupt(args: argparse.Namespace) -> None:
    classes = args.classes.split(",")
    n = 0
    with open(args.out, "w") as out:
        for line in open(args.clean):
            s = line.rstrip("\n")
            if not s:
                continue
            if random.random() > args.rate:
                continue
            rec = corrupt_sentence(s, classes)
            if rec:
                out.write(json.dumps(rec) + "\n")
                n += 1
    print(f"wrote {n} corrupted pairs -> {args.out}")


def cmd_verify(args: argparse.Namespace) -> None:
    """Keep pairs where the teacher restored the known-clean original
    (verified) or produced a minimal variant (kept, flagged)."""
    verified = kept = dropped = 0
    with open(args.corrupted) as cf, open(args.teacher) as tf, open(args.out, "w") as out:
        for cline, tline in zip(cf, tf):
            rec = json.loads(cline)
            teacher = tline.rstrip("\n")
            if teacher == rec["clean"]:
                rec["teacher"] = teacher
                rec["status"] = "verified"
                verified += 1
            else:
                d_clean = rec["clean"].split()
                d_teacher = teacher.split()
                if abs(len(d_clean) - len(d_teacher)) <= 2:
                    rec["teacher"] = teacher
                    rec["status"] = "variant"
                    kept += 1
                else:
                    dropped += 1
                    continue
            out.write(json.dumps(rec) + "\n")
    print(f"verified {verified}, variant {kept}, dropped {dropped}")


def main() -> None:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("corrupt")
    c.add_argument("clean")
    c.add_argument("out")
    c.add_argument("--rate", type=float, default=0.8)
    c.add_argument("--classes", default="ArtOrDet,Prep,Nn,SVA,Wci")
    v = sub.add_parser("verify")
    v.add_argument("corrupted")
    v.add_argument("teacher")
    v.add_argument("out")
    args = ap.parse_args()
    {"corrupt": cmd_corrupt, "verify": cmd_verify}[args.cmd](args)


if __name__ == "__main__":
    main()
