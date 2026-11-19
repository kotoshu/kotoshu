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

MAX_PIECE_BYTES = 16


class SpmUnigram:
    """Viterbi encode over the pruned pieces table — the port of
    lib/kotoshu/experimental/spm_unigram_encoder.rb (148/148
    conformance). Scores are log-probs VERBATIM."""

    def __init__(self, pieces_path):
        pieces = json.load(open(pieces_path))
        self.rows = [p["piece"] for p in pieces]
        self.scores = [float(p.get("score", 0.0)) for p in pieces]
        self.piece_to_row = {}
        for i, p in enumerate(pieces):
            self.piece_to_row.setdefault(p["piece"], i)
        self.unk_row = self.piece_to_row.get("[UNK]", 3)
        self.byte_fallback = {}
        for i, p in enumerate(pieces):
            m = p["piece"].startswith("<0x") and p["piece"].endswith(">")
            if m and len(p["piece"]) == 6:
                try:
                    self.byte_fallback[int(p["piece"][3:5], 16)] = i
                except ValueError:
                    pass

    def encode_words(self, words):
        ids = []
        for w in words:
            ids.extend(self._viterbi("▁" + w))
        return ids

    def _viterbi(self, text):
        data = text.encode("utf-8")
        n = len(data)
        best = [-math.inf] * (n + 1)
        back = [None] * (n + 1)
        best[0] = 0.0
        for end in range(1, n + 1):
            for length in range(min(MAX_PIECE_BYTES, end), 0, -1):
                cand = data[end - length:end]
                row = self.piece_to_row.get(
                    cand.decode("utf-8", errors="ignore"))
                if row is None:
                    continue
                score = best[end - length] + self.scores[row]
                if score > best[end]:
                    best[end] = score
                    back[end] = (end - length, row)
            if back[end] is None:
                fb = self.byte_fallback.get(data[end - 1])
                row = fb if fb is not None else self.unk_row
                pen = self.scores[row] if fb is not None else -20.0
                best[end] = best[end - 1] + pen
                back[end] = (end - 1, row)
        out = []
        pos = n
        while pos > 0:
            prev, row = back[pos]
            out.append(row)
            pos = prev
        return out[::-1]


def main():
    model_dir, src_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    rounds = int(sys.argv[4]) if len(sys.argv) > 4 else 4

    sess = ort.InferenceSession(f"{model_dir}/gec-tagger.int8.onnx",
                                providers=["CPUExecutionProvider"])
    labels = json.load(open(f"{model_dir}/labels.json"))  # {id: label}
    keep_id = next(int(i) for i, l in labels.items() if l == "$KEEP")
    pieces_path = f"{model_dir}/pieces.json"
    if os.path.exists(pieces_path):
        # PRUNED sentencepiece artifact (mdeberta family): encode via the
        # pieces table (row ids match the pruned embedding). The full
        # tokenizer.json overruns the embedding (Gather OOB).
        enc_model = SpmUnigram(pieces_path)

        def encode_words(words):
            ids, word_ids = [], []
            for w_i, w in enumerate(words):
                w_ids = enc_model.encode_words([w])
                ids.extend(w_ids)
                word_ids.extend([w_i] * len(w_ids))
            return ids, word_ids
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
