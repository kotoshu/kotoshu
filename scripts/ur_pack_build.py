"""Build the Urdu corruption pack from the CLE Digest Corpus (PRIVATE data).

License: CLE12T003/CLE12L001 (Ribose<->CLE executed 2026-10). Pack + extracts
stage PRIVATE in kotoshu/gec-training-private ur/ — never public (Schedule C).
Released artifacts = trained weights passing the Clause 16(e) gate + Schedule D
credit.

Balanced error classes (uniform draw — the ko-v11 balanced-class law):
  1 homophone-letter sets (the real Urdu spelling errors)
  2 Arabic<->Urdu letter confusions (imported Arabic spellings)
  3 keyboard adjacency (CRULP phonetic approximations)
  4 transpositions
  5 space errors (compound joins/splits)
  6 real-word swaps grounded in WordNet lemmas (private source)

Usage: python3 ur_pack_build.py [--corpus DIR] [--wordnet TXT] [--out DIR]
"""
import argparse, glob, json, os, random, re, sys

random.seed(20261118)

HOMOPHONES = [
    ["ز", "ذ", "ض", "ظ"],
    ["س", "ص", "ث"],
    ["ت", "ٹ"],
    ["د", "ڈ"],
    ["ر", "ڑ"],
    ["ہ", "ھ"],
    ["ع", "ا"],
    ["گ", "غ"],
]
ARABIC_CONFUSIONS = {"ک": "ك", "ی": "ي", "ئ": "ي", "بے": None}  # ur -> ar direction
ARABIC_CONFUSIONS = {"ک": "ك", "ی": "ي"}
# CRULP Urdu phonetic adjacency approximation (same-row neighbors on the
# phonetic mapping; refined when the layout file lands in the gem)
KB_NEIGHBORS = {
    "ب": ["پ", "ی"], "پ": ["ب"], "ت": ["ٹ", "ط"], "ٹ": ["ت"],
    "ج": ["چ", "ح"], "چ": ["ج"], "د": ["ڈ", "ذ"], "ڈ": ["د"],
    "ر": ["ڑ", "ز"], "ڑ": ["ر"], "ز": ["ژ", "ر"], "ژ": ["ز"],
    "س": ["ش", "ص"], "ش": ["س"], "ص": ["س", "ض"], "ض": ["ص", "ظ"],
    "ط": ["ط", "ت"], "ظ": ["ض"], "غ": ["گ", "ف"], "ف": ["غ"],
    "ق": ["ک", "ف"], "ک": ["ق", "گ"], "گ": ["ک", "غ"],
    "ل": ["ال", "م"], "م": ["ن", "ل"], "ن": ["م", "ہ"],
    "و": ["ؤ", "ہ"], "ہ": ["ی", "ن"], "ی": ["ے", "ہ"], "ے": ["ی"],
    "ا": ["آ", "ع"], "آ": ["ا"],
}
WORDNET_LEMMAS = None  # loaded lazily


def load_sentences(corpus_dir):
    files = sorted(glob.glob(os.path.join(corpus_dir, "**", "*.txt"), recursive=True))
    files = [f for f in files if os.path.basename(f) != "README.txt"]
    sentences = set()
    for fp in files:
        raw = open(fp, encoding="utf-8-sig", errors="ignore").read()
        for s in re.split(r"[۔\?\!\n]+", raw):
            s = s.strip().replace("‌", "").replace("‍", "")
            toks = s.split()
            if 3 <= len(toks) <= 40 and sum(len(t) for t in toks) >= 8:
                sentences.add(" ".join(toks))
    return sorted(sentences)


def pick_word(tokens, rng):
    candidates = [i for i, t in enumerate(tokens) if len(t) >= 3]
    return rng.choice(candidates) if candidates else None


def corrupt_homophone(tokens, rng):
    i = pick_word(tokens, rng)
    if i is None: return None
    w = tokens[i]
    spots = [j for j, ch in enumerate(w) if any(ch in g for g in HOMOPHONES)]
    if not spots: return None
    j = rng.choice(spots)
    group = next(g for g in HOMOPHONES if w[j] in g)
    repl = rng.choice([c for c in group if c != w[j]])
    new = list(w); new[j] = repl
    out = list(tokens); out[i] = "".join(new)
    return out, "homophone"


def corrupt_arabic(tokens, rng):
    for _ in range(6):
        i = pick_word(tokens, rng)
        if i is None: return None
        w = tokens[i]
        spots = [j for j, ch in enumerate(w) if ch in ARABIC_CONFUSIONS]
        if not spots: continue
        j = rng.choice(spots)
        new = list(w); new[j] = ARABIC_CONFUSIONS[w[j]]
        out = list(tokens); out[i] = "".join(new)
        return out, "arabic-confusion"
    return None


def corrupt_keyboard(tokens, rng):
    for _ in range(6):
        i = pick_word(tokens, rng)
        if i is None: return None
        w = tokens[i]
        spots = [j for j, ch in enumerate(w) if ch in KB_NEIGHBORS]
        if not spots: continue
        j = rng.choice(spots)
        repl = rng.choice(KB_NEIGHBORS[w[j]])
        new = list(w); new[j] = repl
        out = list(tokens); out[i] = "".join(new)
        return out, "keyboard"
    return None


def corrupt_transpose(tokens, rng):
    i = pick_word(tokens, rng)
    if i is None or len(tokens[i]) < 4: return None
    w = list(tokens[i])
    j = rng.randrange(len(w) - 2)
    w[j], w[j + 1] = w[j + 1], w[j]
    out = list(tokens); out[i] = "".join(w)
    return out, "transposition"


def corrupt_space(tokens, rng):
    if len(tokens) < 4: return None
    i = rng.randrange(len(tokens) - 1)
    if len(tokens[i]) + len(tokens[i + 1]) < 8: return None
    out = tokens[:i] + [tokens[i] + tokens[i + 1]] + tokens[i + 2:]
    return out, "space-join"


def corrupt_realword(tokens, rng):
    global WORDNET_LEMMAS
    if WORDNET_LEMMAS is None: return None
    for _ in range(6):
        i = pick_word(tokens, rng)
        if i is None: return None
        w = tokens[i]
        if w in WORDNET_LEMMAS and len(WORDNET_LEMMAS) > 1:
            repl = rng.choice(sorted(WORDNET_LEMMAS))
            if repl != w:
                out = list(tokens); out[i] = repl
                return out, "real-word"
    return None


CORRUPTORS = [corrupt_homophone, corrupt_arabic, corrupt_keyboard,
              corrupt_transpose, corrupt_space, corrupt_realword]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", default=os.path.expanduser(
        "~/src/interscript/pk-cle-urdu/CLE Urdu Digest Corpus 1M"))
    ap.add_argument("--wordnet", default="/tmp/ur_lemmas.txt")
    ap.add_argument("--out", default="/tmp/ur_pack")
    ap.add_argument("--draws", type=int, default=3)
    ap.add_argument("--holdout", type=int, default=1500)
    a = ap.parse_args()

    global WORDNET_LEMMAS
    if os.path.exists(a.wordnet):
        WORDNET_LEMMAS = set(l.strip() for l in open(a.wordnet, encoding="utf-8") if l.strip())
        print(f"wordnet lemmas: {len(WORDNET_LEMMAS)}")

    sentences = load_sentences(a.corpus)
    print(f"sentences: {len(sentences)}")
    rng = random.Random(20261118)
    rng.shuffle(sentences)
    heldout = sentences[:a.holdout]
    train = sentences[a.holdout:]

    os.makedirs(a.out, exist_ok=True)
    pairs = []
    classes = {}
    seen = set()
    for s in train:
        toks = s.split()
        for _ in range(a.draws):
            fn = rng.choice(CORRUPTORS)
            res = fn(toks, rng)
            if not res: continue
            new_toks, cls = res
            corrupted = " ".join(new_toks)
            if corrupted == s or (corrupted, s) in seen: continue
            seen.add((corrupted, s))
            pairs.append({"corrupted": corrupted, "clean": s, "cls": cls})
            classes[cls] = classes.get(cls, 0) + 1

    print(f"pack: {len(pairs)} pairs, classes: {classes}")
    with open(os.path.join(a.out, "ur_v1_pairs.jsonl"), "w", encoding="utf-8") as f:
        for p in pairs:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")
    with open(os.path.join(a.out, "ur_v1_heldout_sources.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(heldout) + "\n")
    with open(os.path.join(a.out, "ur_v1_heldout_gold.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(heldout) + "\n")
    with open(os.path.join(a.out, "base_ur.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(train[:30000]) + "\n")
    print(f"heldout: {len(heldout)} (gate slice: sources == gold, clean text)")
    print(f"base_ur prune corpus: {min(30000, len(train))} sentences")


if __name__ == "__main__":
    main()
