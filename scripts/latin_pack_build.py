"""Balanced corruption pack builder for Latin-script languages
(Generalization of ur_pack_build.py — issue #271, the Urdu template).

Word sources: the kotoshu/dictionaries repo per-language hunspell
index.dic (public, licensed) — corruption vocabulary is already
licensed. Sentence source: the language's module-level corpus or a
supplied text file (PRIVATE staging for any licensed corpus).

Classes (uniform draw): keyboard adjacency (qwerty/qwertz via the gem's
layout grids, approximated here), transposition, vowel/diacritic
substitution (language diacritic sets), double-letter fix, space join,
real-word swap (dictionary-grounded).

Usage:
  python3 latin_pack_build.py --lang it --dict ~/src/kotoshu/dictionaries/it/index.dic \
      --corpus /path/to/it_sentences.txt --out /tmp/it_pack [--draws 3]
"""
import argparse, json, os, random, re, sys

QWERTY_ADJ = {
    "q": "wa", "w": "qesd", "e": "wrds", "r": "etdf", "t": "ryfg",
    "y": "tugh", "u": "yihj", "i": "uojk", "o": "ipkl", "p": "ol",
    "a": "qsz", "s": "adxz", "d": "sfcx", "f": "dgv", "g": "fhb",
    "h": "gjn", "j": "hkm", "k": "jlm", "l": "kop",
    "z": "ax", "x": "zsc", "c": "xvb", "v": "cbn", "b": "vn", "n": "bm", "m": "n",
}
DIACRITICS = {
    "it": {"à": "a", "è": "e", "é": "e", "ì": "i", "ò": "o", "ù": "u"},
    "fr": {"à": "a", "â": "a", "é": "e", "è": "e", "ê": "e", "ë": "e",
           "î": "i", "ï": "i", "ô": "o", "û": "u", "ù": "u", "ç": "c"},
    "pt": {"á": "a", "â": "a", "ã": "a", "é": "e", "ê": "e", "í": "i",
           "ó": "o", "õ": "o", "ú": "u", "ç": "c"},
    "pl": {"ą": "a", "ć": "c", "ę": "e", "ł": "l", "ń": "n", "ó": "o",
           "ś": "s", "ź": "z", "ż": "z"},
    "nl": {},
    "tr": {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u"},
    "uk": {"а": "я", "и": "и", "є": "е", "ї": "і", "ґ": "г"},
    "el": {"ά": "α", "έ": "ε", "ή": "η", "ί": "ι", "ό": "ο", "ύ": "υ", "ώ": "ω",
           "ς": "σ"},
    "sr": {"ђ": "ђ", "ј": "j", "љ": "љ", "њ": "њ", "ћ": "ћ", "џ": "џ"},
}

# Wave-2 per-script keyboard adjacency (extracted from the gem's layout
# coordinate grids — scripts/extract_layout_adjacency.py).
try:
    SCRIPT_ADJ = json.load(open(__file__.rsplit("/", 1)[0] + "/wave2_adjacency.json",
                                encoding="utf-8"))
except Exception:
    SCRIPT_ADJ = {}


def load_dict_words(dic_path, min_len=3):
    words = set()
    for line in open(dic_path, encoding="utf-8", errors="ignore"):
        w = line.split("/", 1)[0].strip()
        if len(w) >= min_len and w.isalpha():
            words.add(w.lower())
    return words


def load_sentences(path):
    sentences = set()
    for line in open(path, encoding="utf-8", errors="ignore"):
        s = line.strip()
        toks = s.split()
        if 4 <= len(toks) <= 40:
            sentences.add(" ".join(toks))
    return sorted(sentences)


def pick_word(tokens, rng):
    c = [i for i, t in enumerate(tokens) if len(t) >= 4]
    return rng.choice(c) if c else None


def make_corruptors(lang, dict_words, rng):
    diac = DIACRITICS.get(lang, {})
    qwerty = SCRIPT_ADJ.get(lang, QWERTY_ADJ)

    def keyboard(tokens):
        i = pick_word(tokens, rng)
        if i is None: return None
        w = list(tokens[i])
        spots = [j for j, ch in enumerate(w) if ch.lower() in qwerty]
        if not spots: return None
        j = rng.choice(spots)
        w[j] = rng.choice(qwerty[w[j].lower()])
        out = list(tokens); out[i] = "".join(w)
        return out, "keyboard"

    def transposition(tokens):
        i = pick_word(tokens, rng)
        if i is None or len(tokens[i]) < 4: return None
        w = list(tokens[i])
        j = rng.randrange(len(w) - 1)
        w[j], w[j + 1] = w[j + 1], w[j]
        out = list(tokens); out[i] = "".join(w)
        return out, "transposition"

    def diacritic(tokens):
        if not diac: return None
        for _ in range(6):
            i = pick_word(tokens, rng)
            if i is None: return None
            w = list(tokens[i])
            spots = [j for j, ch in enumerate(w) if ch in diac]
            if not spots: continue
            j = rng.choice(spots)
            w[j] = diac[w[j]]
            out = list(tokens); out[i] = "".join(w)
            return out, "diacritic"
        return None

    def double_letter(tokens):
        i = pick_word(tokens, rng)
        if i is None: return None
        w = list(tokens[i])
        pairs = [j for j in range(len(w) - 1) if w[j] == w[j + 1]]
        spots = pairs if pairs else None
        if not spots: return None
        j = rng.choice(pairs)
        del w[j]  # drop one of the doubled pair
        out = list(tokens); out[i] = "".join(w)
        return out, "double-letter"

    def space_join(tokens):
        if len(tokens) < 4: return None
        i = rng.randrange(len(tokens) - 1)
        if len(tokens[i]) + len(tokens[i + 1]) < 8: return None
        out = tokens[:i] + [tokens[i] + tokens[i + 1]] + tokens[i + 2:]
        return out, "space-join"

    def real_word(tokens):
        if not dict_words: return None
        for _ in range(6):
            i = pick_word(tokens, rng)
            if i is None: return None
            w = tokens[i].lower()
            if w in dict_words:
                repl = rng.choice(sorted(dict_words))
                if repl != w:
                    out = list(tokens); out[i] = repl
                    return out, "real-word"
        return None

    return [keyboard, transposition, diacritic, double_letter, space_join, real_word]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    ap.add_argument("--dict", required=True)
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--draws", type=int, default=3)
    ap.add_argument("--holdout", type=int, default=1500)
    ap.add_argument("--seed", type=int, default=20261119)
    a = ap.parse_args()

    rng = random.Random(a.seed)
    dict_words = load_dict_words(a.dict)
    print(f"dict words: {len(dict_words)}")
    sentences = load_sentences(a.corpus)
    print(f"sentences: {len(sentences)}")
    rng.shuffle(sentences)
    heldout = sentences[:a.holdout]
    train = sentences[a.holdout:]

    corruptors = make_corruptors(a.lang, dict_words, rng)
    os.makedirs(a.out, exist_ok=True)
    pairs, classes, seen = [], {}, set()
    for s in train:
        toks = s.split()
        for _ in range(a.draws):
            fn = rng.choice(corruptors)
            res = fn(toks)
            if not res: continue
            new_toks, cls = res
            corrupted = " ".join(new_toks)
            if corrupted == s or (corrupted, s) in seen: continue
            seen.add((corrupted, s))
            pairs.append({"corrupted": corrupted, "clean": s, "cls": cls})
            classes[cls] = classes.get(cls, 0) + 1
    print(f"pack: {len(pairs)} pairs, classes: {classes}")

    with open(os.path.join(a.out, f"{a.lang}_v1_pairs.jsonl"), "w", encoding="utf-8") as f:
        for p in pairs:
            f.write(json.dumps(p, ensure_ascii=False) + "\n")
    with open(os.path.join(a.out, f"{a.lang}_v1_heldout_sources.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(heldout) + "\n")
    with open(os.path.join(a.out, f"{a.lang}_v1_heldout_gold.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(heldout) + "\n")
    with open(os.path.join(a.out, f"base_{a.lang}.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(train[:30000]) + "\n")


if __name__ == "__main__":
    main()
