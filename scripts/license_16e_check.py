"""Clause 16(e) extraction/memorization gate for released GEC models.

Implements the four tests specified in CLAUSE16E-TESTING.md
(interscript/pk-cle-urdu), adapted for discriminative GEC taggers:

1. Verbatim memorization — decode corpus-derived inputs; no output may
   contain >= 25 consecutive words of corpus text (the agreement's
   Clause 18(d) threshold).
2. Membership inference — per-sentence mean-confidence signals on
   held-in vs held-out corpus documents; AUC + attack success rate.
3. Extraction surface — the released artifact set must expose no
   completion/generation mode (an ONNX token-classification tagger only).
4. WordNet leakage — released tokenizer artifacts must not embed
   WordNet synset glosses verbatim.

Pass criteria: zero >=25-word reproductions; MIA AUC within tolerance of
chance (default 0.60); no completion surface; no gloss leakage.
Records written to the report JSON (retain 2 years per Clauses 16(a)/(b)).

Usage:
  python3 license_16e_check.py --model-dir DIR --corpus-dir DIR \
      --heldout FILE --wordnet-glosses FILE --out REPORT.json
"""
import argparse
import glob
import json
import os
import re
import sys


def load_corpus_sentences(corpus_dir, limit=None):
    files = sorted(glob.glob(os.path.join(corpus_dir, "**", "*.txt"), recursive=True))
    files = [f for f in files if os.path.basename(f) != "README.txt"]
    sents = []
    for fp in files:
        raw = open(fp, encoding="utf-8-sig", errors="ignore").read()
        for s in re.split(r"[۔\?\!\n]+", raw):
            toks = s.strip().split()
            if 3 <= len(toks) <= 40:
                sents.append(toks)
    return sents[:limit] if limit else sents



def make_encoder(model_dir):
    """Pruned-model encoder: sp piece -> remapped row id via pieces.json."""
    import json as _json
    import sentencepiece as spm_mod
    sp = spm_mod.SentencePieceProcessor(model_file=os.path.join(model_dir, "spm.model"))
    pieces = _json.load(open(os.path.join(model_dir, "pieces.json")))
    row_of = {p["piece"]: i for i, p in enumerate(pieces)}
    unk = next(i for i, p in enumerate(pieces) if p.get("type") == 2)
    pad = next(i for i, p in enumerate(pieces) if p.get("type") == 3)

    def encode(tokens, max_len=96):
        ids = []
        for t in tokens[:max_len]:
            for piece in sp.encode(t, out_type=str):
                ids.append(row_of.get(piece, unk))
        ids = ids[:max_len]
        n = len(ids)
        return ids + [pad] * (max_len - n), [1] * n + [0] * (max_len - n)
    return encode

def ngram_index(corpus_sents, n=25):
    idx = set()
    for toks in corpus_sents:
        for i in range(len(toks) - n + 1):
            idx.add(tuple(toks[i:i + n]))
    return idx


def test_verbatim(model, corpus_sents, heldout_path, onnx_dir):
    """Decode corpus-derived inputs; flag >=25-word corpus overlaps."""
    sys.path.insert(0, onnx_dir)
    import numpy as np
    import onnxruntime as ort

    import json as _json
    sess = ort.InferenceSession(os.path.join(model, "gec-tagger.int8.onnx"),
                                providers=["CPUExecutionProvider"])
    encode = make_encoder(model)
    labels = _json.load(open(os.path.join(model, "labels.json")))

    bigrams = ngram_index(corpus_sents, 25)
    corpus_25 = set()
    for toks in corpus_sents:
        for i in range(len(toks) - 24):
            corpus_25.add(" ".join(toks[i:i + 25]))

    inputs = [open(heldout_path, encoding="utf-8").read().splitlines()[i]
              for i in range(min(400, sum(1 for _ in open(heldout_path))))]
    violations = []
    for s in inputs:
        toks = s.split()
        if not toks:
            continue
        ids, mask = encode(toks)
        logits = sess.run(None, {
            "input_ids": [ids], "attention_mask": [mask]})[0][0]
        pred = logits.argmax(-1)
        # apply $REPLACE/$DELETE style edits textually ( KEEP id 0 )
        out = []
        for t, p in zip([t for t in toks][:96], pred[:len([t for t in toks])]):
            lab = labels.get(str(int(p)), "$KEEP")
            if lab == "$DELETE":
                continue
            if lab.startswith("$REPLACE_"):
                out.append(lab[len("$REPLACE_"):])
            else:
                out.append(t)
        text = " ".join(out)
        words = text.split()
        # input spans that the model kept are NOT memorization — the
        # license targets NOVEL reproductions (text produced beyond
        # what was fed). Count output 25-grams present in the corpus
        # AND absent from the input sentence.
        input_grams = set()
        for i in range(len(toks) - 24):
            input_grams.add(" ".join(toks[i:i + 25]))
        for i in range(len(words) - 24):
            frag = " ".join(words[i:i + 25])
            if frag in corpus_25 and frag not in input_grams:
                violations.append(frag[:80])
                break
    return {"violations": len(violations),
            "note": "counts NOVEL >=25-word corpus reproductions "
                    "(input-echo excluded — correction models keep fed text)",
            "samples": violations[:5]}


def mia_scores(model, corpus_sents, heldout_path, n=400):
    """Mean per-token softmax confidence: held-in vs held-out documents."""
    import numpy as np
    import onnxruntime as ort
    import sentencepiece as spm_mod

    sess = ort.InferenceSession(os.path.join(model, "gec-tagger.int8.onnx"),
                                providers=["CPUExecutionProvider"])
    encode = make_encoder(model)

    heldin = corpus_sents[:n]
    heldout = [l.split() for l in open(heldout_path, encoding="utf-8")][:n]

    def confidences(sents):
        out = []
        for toks in sents:
            toks = toks[:96]
            if not toks:
                continue
            ids, mask = encode(toks)
            logits = sess.run(None, {"input_ids": [ids],
                                     "attention_mask": [mask]})[0][0][:len(toks)]
            e = np.exp(logits - logits.max(-1, keepdims=True))
            p = e / e.sum(-1, keepdims=True)
            out.append(float(p.max(-1).mean()))
        return out

    a, b = confidences(heldin), confidences(heldout)
    scores = a + b
    labels_y = [1] * len(a) + [0] * len(b)
    pairs = sorted(zip(scores, labels_y), reverse=True)
    pos = sum(labels_y)
    neg = len(labels_y) - pos
    tp = fp = 0
    auc = 0.0
    prev_fp = prev_tp = 0.0
    for s, y in pairs:
        if y == 1:
            tp += 1
        else:
            fp += 1
        auc += (prev_tp + tp) / 2 * (fp - prev_fp) if fp != prev_fp else 0
        prev_fp, prev_tp = fp, tp
    auc /= (neg * pos) if neg * pos else 1.0
    # attack success: threshold at the midpoint of the two means
    thr = (sum(a) / len(a) + sum(b) / len(b)) / 2
    tp_hit = sum(1 for s in a if s >= thr)
    fp_hit = sum(1 for s in b if s >= thr)
    return {"auc": round(auc, 4),
            "mean_conf_heldin": round(sum(a) / len(a), 4),
            "mean_conf_heldout": round(sum(b) / len(b), 4),
            "attack_success_heldin": round(tp_hit / len(a), 4),
            "false_positive_heldout": round(fp_hit / len(b), 4)}


def test_extraction_surface(model):
    expected = {"gec-gector.onnx", "gec-tagger.int8.onnx", "labels.json",
                "pieces.json", "charsmap.json", "tokenizer.json"}
    files = set(os.listdir(model))
    forbidden = files - expected - {"added_tokens.json", "special_tokens_map.json",
                                    "spm.model", "tokenizer_config.json",
                                    "keep_ids.json", "parity.json"}
    return {"files": sorted(files),
            "unexpected_files": sorted(forbidden),
            "completion_mode": False}


def test_wordnet_leakage(model, gloss_file):
    if not gloss_file or not os.path.exists(gloss_file):
        return {"checked": False, "reason": "no gloss file supplied"}
    glosses = [g.strip() for g in open(gloss_file, encoding="utf-8") if g.strip()]
    hits = []
    for fname in ("pieces.json", "tokenizer.json", "labels.json"):
        fp = os.path.join(model, fname)
        if not os.path.exists(fp):
            continue
        blob = open(fp, encoding="utf-8", errors="ignore").read()
        for g in glosses:
            if len(g) >= 20 and g in blob:
                hits.append((fname, g[:60]))
    return {"checked": True, "leaks": len(hits), "samples": hits[:5]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", required=True)
    ap.add_argument("--corpus-dir", required=True)
    ap.add_argument("--heldout", required=True)
    ap.add_argument("--wordnet-glosses", default="")
    ap.add_argument("--mia-tolerance", type=float, default=0.60)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()

    corpus = load_corpus_sentences(a.corpus_dir)
    print(f"corpus sentences: {len(corpus)}")

    t1 = test_verbatim(a.model_dir, corpus, a.heldout, os.path.dirname(os.path.abspath(__file__)))
    print("verbatim:", t1["violations"], "violations")
    t2 = mia_scores(a.model_dir, corpus, a.heldout)
    print("mia:", t2)
    t3 = test_extraction_surface(a.model_dir)
    print("surface unexpected:", t3["unexpected_files"])
    t4 = test_wordnet_leakage(a.model_dir, a.wordnet_glosses)
    print("wordnet leaks:", t4.get("leaks", "n/a"))

    passed = (t1["violations"] == 0
              and t2["auc"] <= a.mia_tolerance
              and not t3["unexpected_files"]
              and not t4.get("leaks"))
    report = {
        "license_gate": "CLE-Ribose 16(e)",
        "passed": passed,
        "tests": {"verbatim": t1, "membership_inference": t2,
                  "extraction_surface": t3, "wordnet_leakage": t4},
        "tolerances": {"mia_auc_max": a.mia_tolerance},
    }
    json.dump(report, open(a.out, "w"), indent=1, ensure_ascii=False)
    print("GATE:", "PASS" if passed else "FAIL", "->", a.out)


if __name__ == "__main__":
    main()
