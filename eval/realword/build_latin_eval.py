"""Build held-out eval splits for the Latin wave packs: corrupt the
pack's held-out clean sentences with the SAME builder classes (fixed
seed) so the gate measures correction of the trained corruption
distribution. Emits {lang}_heldout_eval_sources.txt (corrupted inputs)
and {lang}_heldout_gold.tsv (corrupted\tclean) for gold_score.py.
"""
import json
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "scripts"))
import importlib.util

spec = importlib.util.spec_from_file_location(
    "lpb", os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "..", "..", "scripts", "latin_pack_build.py"))
lpb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lpb)

CORP = os.path.expanduser("~/.cache/kotoshu-gec/corpora")
DICTS = {"nl": "nl", "pl": "pl", "pt": "pt-PT", "it": "it",
         "uk": "uk", "tr": "tr", "el": "el", "sr": "sr"}


def main(lang):
    held = os.path.join(CORP, f"{lang}_pack", f"{lang}_v1_heldout_sources.txt")
    dict_words = lpb.load_dict_words(
        os.path.expanduser(f"~/src/kotoshu/dictionaries/{DICTS[lang]}/index.dic"))
    sentences = [l.strip() for l in open(held, encoding="utf-8") if l.strip()]
    rng = random.Random(20261118 + len(lang))
    corruptors = lpb.make_corruptors(lang, dict_words, rng)
    sources, gold = [], []
    for s in sentences:
        toks = s.split()
        made = None
        for _ in range(4):
            fn = rng.choice(corruptors)
            res = fn(toks)
            if res:
                made = res
                break
        if not made:
            continue
        corrupted = " ".join(made[0])
        if corrupted == s:
            continue
        sources.append(corrupted)
        gold.append(f"{corrupted}\t{s}")
    base = os.path.join(CORP, f"{lang}_heldout_eval_sources.txt")
    open(base, "w", encoding="utf-8").write("\n".join(sources) + "\n")
    open(base.replace("_sources.txt", "_gold.tsv"), "w", encoding="utf-8") \
        .write("\n".join(gold) + "\n")
    print(f"{lang}: {len(sources)} eval pairs -> {base}")


if __name__ == "__main__":
    for lang in sys.argv[1:] or ["nl", "pl", "pt"]:
        main(lang)
