"""Python-ORT GECToR decoder — mirrors lib/kotoshu/grammar/gector_decoder.rb
+ ByteBpe exactly (rounds, right-to-left apply, REPLACE_x/APPEND_x/DELETE,
per-word first-subtoken argmax, 512-position window cap). The HF tokenizers
path is the training-time tokenization (the gem's ByteBpe port conforms to
it), so this decoder is byte-faithful for roberta-family artifacts.

Usage: python3 decode_ort_py.py MODEL_DIR SOURCES.txt OUT.txt [ROUNDS]
"""
import json
import math
import os
import sys

import onnxruntime as ort
from tokenizers import Tokenizer

MAX_PIECE_CHARS = 32
CLS, SEP = 1, 2
METASPACE = "▁"


class SpmBpePort:
    """The exact port of lib/kotoshu/grammar/spm_bpe.rb (the mdeberta
    serving encoder — fixture-frozen vs DebertaV2TokenizerFast):
    charsmap normalization + NFC, per-word metaspace, CHAR-level
    unigram Viterbi over piece scores, min-score unknowns fused into
    single [UNK], CLS/SEP framing in encode_words."""

    def __init__(self, pieces_path, charsmap_path):
        self.piece_id = {}
        self.piece_score = {}
        scores = []
        for i, p in enumerate(json.load(open(pieces_path))):
            if p.get("type") == 6:
                continue
            self.piece_id[p["piece"]] = i
            self.piece_score[p["piece"]] = p["score"]
            scores.append(p["score"])
        self.unk_score = min(scores)
        self.unk = self.piece_id["[UNK]"]
        self.chars = json.load(open(charsmap_path))
        self.cache = {}

    def normalize(self, text):
        import unicodedata
        text = unicodedata.normalize("NFC", text)
        return "".join(self.chars.get(f"{ord(c):04X}", c) for c in text)

    def word_ids(self, word):
        if word not in self.cache:
            piece = METASPACE + self.normalize(word).replace(" ", METASPACE)
            self.cache[word] = self.segment_ids(piece)
        return self.cache[word]

    def encode_words(self, words):
        ids = [CLS]
        word_ids = [None]
        for i, w in enumerate(words):
            wids = self.word_ids(str(w))
            ids.extend(wids)
            word_ids.extend([i] * len(wids))
        ids.append(SEP)
        word_ids.append(None)
        return ids, word_ids

    def segment_ids(self, piece):
        whole = self.piece_id.get(piece)
        if whole is not None:
            return [whole]
        n = len(piece)
        best = [-math.inf] * (n + 1)
        best[0] = 0.0
        back = [None] * (n + 1)
        for end_i in range(1, n + 1):
            for start in range(max(end_i - MAX_PIECE_CHARS, 0), end_i):
                prev = best[start]
                if prev == -math.inf:
                    continue
                sub = piece[start:end_i]
                pid = self.piece_id.get(sub)
                if pid is not None:
                    score = self.piece_score[sub]
                elif end_i - start == 1:
                    score = self.unk_score
                else:
                    continue
                total = prev + score
                if total > best[end_i]:
                    best[end_i] = total
                    back[end_i] = end_i - start
        segs = []
        pos = n
        while pos > 0:
            ln = back[pos]
            segs.insert(0, piece[pos - ln:pos])
            pos -= ln
        out = []
        unknown_run = False
        for seg in segs:
            if seg in self.piece_id:
                out.append(self.piece_id[seg])
                unknown_run = False
            else:
                if not unknown_run:
                    out.append(self.unk)
                    unknown_run = True
        return out


def main():
    model_dir, src_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    rounds = int(sys.argv[4]) if len(sys.argv) > 4 else 4

    sess = ort.InferenceSession(f"{model_dir}/gec-tagger.int8.onnx",
                                providers=["CPUExecutionProvider"])
    labels = json.load(open(f"{model_dir}/labels.json"))  # {id: label}
    keep_id = next(int(i) for i, l in labels.items() if l == "$KEEP")
    pieces_path = f"{model_dir}/pieces.json"
    if os.path.exists(pieces_path):
        # PRUNED sentencepiece artifact (mdeberta family): the exact
        # SpmBpe serving encoder (charsmap + metaspace + char-viterbi).
        enc_model = SpmBpePort(pieces_path,
                               f"{model_dir}/charsmap.json")

        def encode_words(words):
            return enc_model.encode_words(words)
    else:
        tok = Tokenizer.from_file(f"{model_dir}/tokenizer.json")

        def encode_words(words):
            enc = tok.encode(" ".join(words))
            return enc.ids, enc.word_ids

    def apply(label, tokens, index):
        if label.startswith("$REPLACE_"):
            out = list(tokens)
            out[index] = label[len("$REPLACE_"):]
            return out
        if label.startswith("$APPEND_"):
            out = list(tokens)
            out[index + 1:index + 1] = label[len("$APPEND_"):].split()
            return out
        if label == "$DELETE":
            out = list(tokens)
            del out[index]
            return out
        return None

    out_lines = []
    for line in open(src_path, encoding="utf-8"):
        line = line.rstrip("\n")
        words = line.split() if line else []
        tokens = words[:]
        for _ in range(rounds):
            changed = False
            if tokens:
                ids, word_ids = encode_words(tokens)
                if len(ids) > 512:
                    ids = ids[:512]
                    word_ids = word_ids[:512]
                logits = sess.run(None, {
                    "input_ids": [ids],
                    "attention_mask": [[1] * len(ids)],
                })[0][0]
                per_word = {}
                for pos, w in enumerate(word_ids):
                    if w is None or w in per_word or w >= len(tokens):
                        continue
                    row = logits[pos]
                    per_word[w] = (int(row.argmax()), tokens[w])
                edits = []
                for w, (lab_id, _) in per_word.items():
                    if lab_id == keep_id or w >= len(tokens):
                        continue
                    edits.append((w, labels[str(lab_id)]))
                for w, label in sorted(edits, reverse=True):
                    result = apply(label, tokens, w)
                    if result is not None:
                        tokens = result
                        changed = True
            if not changed:
                break
        out_lines.append(" ".join(tokens))
    open(out_path, "w", encoding="utf-8").write("\n".join(out_lines) + "\n")
    print(f"decoded {len(out_lines)} lines -> {out_path}")


if __name__ == "__main__":
    main()
