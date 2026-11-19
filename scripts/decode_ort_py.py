"""Python-ORT GECToR decoder — mirrors lib/kotoshu/grammar/gector_decoder.rb
+ ByteBpe exactly (rounds, right-to-left apply, REPLACE_x/APPEND_x/DELETE,
per-word first-subtoken argmax, 512-position window cap). The HF tokenizers
path is the training-time tokenization (the gem's ByteBpe port conforms to
it), so this decoder is byte-faithful for roberta-family artifacts.

Usage: python3 decode_ort_py.py MODEL_DIR SOURCES.txt OUT.txt [ROUNDS]
"""
import json
import sys

import onnxruntime as ort
from tokenizers import Tokenizer


def main():
    model_dir, src_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
    rounds = int(sys.argv[4]) if len(sys.argv) > 4 else 4

    sess = ort.InferenceSession(f"{model_dir}/gec-tagger.int8.onnx",
                                providers=["CPUExecutionProvider"])
    labels = json.load(open(f"{model_dir}/labels.json"))  # {id: label}
    keep_id = next(int(i) for i, l in labels.items() if l == "$KEEP")
    tok = Tokenizer.from_file(f"{model_dir}/tokenizer.json")
    cfg = json.load(open(f"{model_dir}/tokenizer_config.json"))
    if cfg.get("add_prefix_space"):
        tok.pre_tokenizer.prefix = None  # already in post-processor? ensure:
    # roberta byte-bpe: the fast tokenizer adds the prefix space via the
    # Sequence post-processor only when add_prefix_space was set at build.
    # The training path used RobertaTokenizerFast(add_prefix_space=True)
    # over pretokenized words — replicate: prepend ' ' to each word.

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
