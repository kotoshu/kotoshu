"""Registry-driven corruption engine (KLF).

Implements the closed primitive set over YAML class tables
(factory/registry/<lang>.yaml). Languages whose SOTA technique needs
more than these primitives keep their proven dedicated engines
(scripts/corrupt_and_distill.py, corrupt_multilingual.py, ...) — the
orchestrator routes to them via `route: legacy_*` declarations.
Per-language SOTA techniques are pluggable; the pipeline is shared.
"""
import argparse
import json
import random

try:
    import yaml
except ImportError:
    yaml = None


def numeric(tok):
    return any(c.isdigit() for c in tok)


def corrupt_tokens(words, classes, rng, rate):
    """classes: ordered list of (name, spec). Returns corrupted word list or None."""
    if rng.random() > rate:
        return None
    name, spec = rng.choice(classes)
    op = spec["op"]
    table = spec.get("table", {})
    idxs = list(range(len(words)))
    rng.shuffle(idxs)
    for i in idxs:
        w = words[i]
        if op == "swap":
            if w in table:
                repl = table[w][rng.randrange(len(table[w]))]
                return words[:i] + [repl] + words[i + 1:]
        elif op == "context_swap":
            if spec.get("prev_numeric") and i > 0 and numeric(words[i - 1]) and w in table:
                repl = table[w][rng.randrange(len(table[w]))]
                return words[:i] + [repl] + words[i + 1:]
        elif op == "drop":
            if w in table:
                return words[:i] + words[i + 1:]
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("registry_yaml")
    ap.add_argument("segmented_tsv", help="sentence\\tseg1 seg2 ...")
    ap.add_argument("out")
    ap.add_argument("--rate", type=float, default=None)
    ap.add_argument("--seed", type=int, default=20261017)
    a = ap.parse_args()
    assert yaml, "pip install pyyaml"
    reg = yaml.safe_load(open(a.registry_yaml))
    rng = random.Random(a.seed)
    classes = list(reg["classes"].items())
    rate = a.rate or reg.get("rate", 0.8)
    n = 0
    with open(a.out, "w") as out:
        for line in open(a.segmented_tsv):
            s, _, words_str = line.rstrip("\n").partition("\t")
            if not words_str:
                continue
            words = words_str.split(" ")
            new = corrupt_tokens(words, classes, rng, rate)
            if new is not None:
                out.write(json.dumps({"class": "reg", "src": s, "clean": s,
                                      "corrupted": "".join(new)},
                                     ensure_ascii=False) + "\n")
                n += 1
    print(f"wrote {n} corrupted pairs -> {a.out}")


if __name__ == "__main__":
    main()
