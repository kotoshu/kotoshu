"""GECToR-style grammar tagger: training + int8 ONNX export (Modal).

The local-model path (TODO.grammar/9, <200 MB, no cloud at runtime):

  public-domain clean text (Gutenberg et al.)
      -> scripts/error_injector.rb     (our own error taxonomy)
      -> token-aligned (clean, corrupted, edits) JSONL
      -> THIS SCRIPT: distilroberta-base tagger, GECToR-style labels
      -> int8 ONNX  (~85 MB encoder + ~10 MB labels)
      -> shipped through the existing model cache; runs in Ruby
         (onnxruntime), Rust (ort), and the browser (onnxruntime-web)

Everything is ours: the corpus is public domain, the errors are ours,
the weights are trained by us. Nothing to attribute, nothing to
relicense. No user content ever leaves the machine at runtime.

Usage (after `modal token new`):
  modal run scripts/train_tagger_modal.py --data injected.jsonl
"""

from __future__ import annotations

import json
import os

import modal

SIZE_BUDGET_MB = 200
BASE_MODEL = "distilroberta-base"  # 6-layer, 82M params; int8 ~ 85 MB
EPOCHS = 4
LR = 1e-4
BATCH = 16
MAX_LEN = 96

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install(
        "torch",
        "transformers",
        "datasets",
        "onnx",
        "onnxruntime",
        "onnxscript",
        "accelerate",
    )
)

app = modal.App("kotoshu-gec-tagger")


# Closed error-class taxonomy (mirrors lib/kotoshu/grammar/rules/en):
# the tagger DETECTS which token carries which error class; the RULES
# generate the concrete fix. Open-vocab $REPLACE_<word> labels were
# measured NOT to converge (0% end-to-end at 3k AND 27k pairs — the
# replacement set is the open vocabulary of clean words).
CLOSED_LABELS = [
    "$AGREEMENT_3SG",      # walks -> walk (plural/1st subject)
    "$AGREEMENT_WAS_WERE", # was <-> were
    "$AGREEMENT_MODAL_OF", # would have -> would of
    "$CAPITALIZATION",     # I -> i
    "$ARTICLE",            # a <-> an
    "$DETERMINER_NUMBER",  # this <-> these
    "$SPELLING",           # letter doubled/dropped
]


def build_label_vocab(rows: list[dict]) -> dict[str, int]:
    """Closed-class labels: $KEEP plus one label per injector error
    class (edit['class'] when present; legacy files fall back to
    classifying by the edit's source/target pair)."""
    labels = {"$KEEP": 0}
    for label in CLOSED_LABELS:
        labels[label] = len(labels)
    return labels


def closed_label_for(edit: dict) -> str:
    cls = edit.get("class")
    mapping = {
        "verb_3sg_to_base": "$AGREEMENT_3SG",
        "was_were": "$AGREEMENT_WAS_WERE",
        "modal_of": "$AGREEMENT_MODAL_OF",
        "capitalization": "$CAPITALIZATION",
        "article_swap": "$ARTICLE",
        "this_these": "$DETERMINER_NUMBER",
        "letter_tweak": "$SPELLING",
    }
    if cls in mapping:
        return mapping[cls]
    # legacy (class-less) files: infer
    src, tgt = edit.get("src", ""), edit.get("tgt", "") or ""
    if src.lower() == "i":
        return "$CAPITALIZATION"
    if {src.lower(), tgt.lower()} == {"was", "were"}:
        return "$AGREEMENT_WAS_WERE"
    if tgt.lower() == "of" or src.lower() == "of":
        return "$AGREEMENT_MODAL_OF"
    if {src.lower(), tgt.lower()} <= {"a", "an"}:
        return "$ARTICLE"
    if {src.lower(), tgt.lower()} <= {"this", "these"}:
        return "$DETERMINER_NUMBER"
    if tgt and src.lower().rstrip("s") == tgt.lower().rstrip("s") and src.lower().endswith("s"):
        return "$AGREEMENT_3SG"
    return "$SPELLING"


def row_to_labels(row: dict, word_list: list[str], labels: dict[str, int]) -> list[int]:
    """Per-word label ids: default $KEEP, edits override with their
    CLOSED class label."""
    by_src = {edit["src_idx"]: edit for edit in row["edits"]}
    out = []
    for idx in range(len(word_list)):
        edit = by_src.get(idx)
        if edit is None:
            out.append(labels["$KEEP"])
        else:
            out.append(labels.get(closed_label_for(edit), labels["$KEEP"]))
    return out


def evaluate(model, tokenizer, labels: dict, dev_path: str):
    """Held-out closed-class metrics on sentence-disjoint pairs:
    token accuracy, error-class accuracy on corrupted tokens, and
    sentence-level detection (any non-KEEP predicted on a corrupted
    sentence)."""
    import torch

    model.eval()
    rows = [json.loads(l) for l in open(dev_path) if l.strip()]
    tok_correct = 0
    tok_total = 0
    err_correct = 0
    err_total = 0
    detected = 0
    n = len(rows)
    with torch.no_grad():
        for row in rows:
            words = row["corrupted"].split()
            gold = row_to_labels(row, words, labels)
            enc = tokenizer(words, is_split_into_words=True, truncation=True,
                            max_length=MAX_LEN, return_tensors="pt")
            logits = model(**{k: v.to(model.device) for k, v in enc.items()}).logits
            word_ids = enc.word_ids()
            pred_word = {}
            for pos, wid in enumerate(word_ids):
                if wid is not None and wid not in pred_word:
                    pred_word[wid] = logits[0, pos].argmax().item()
            any_flag = False
            for idx in range(len(words)):
                pred = pred_word.get(idx, 0)
                tok_total += 1
                tok_correct += pred == gold[idx]
                if gold[idx] != 0:
                    err_total += 1
                    err_correct += pred == gold[idx]
                if pred != 0:
                    any_flag = True
            detected += any_flag
    return {
        "dev_pairs": n,
        "token_accuracy": round(tok_correct / max(tok_total, 1), 4),
        "error_class_accuracy_on_corrupted": round(err_correct / max(err_total, 1), 4),
        "sentence_detection": round(detected / n, 4),
    }


@app.function(
    image=image,
    gpu="A10G",
    timeout=60 * 60 * 4,
    volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)},
)
def train(data_path: str = "/data/injected.jsonl", out_path: str = "/data/gec-tagger"):
    import torch
    from transformers import AutoModelForTokenClassification, AutoTokenizer, TrainingArguments, Trainer

    rows = []
    with open(data_path) as fh:
        for line in fh:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    print(f"training pairs: {len(rows)}")

    labels = build_label_vocab(rows)
    print(f"label vocab: {len(labels)} (KEEP + {len(labels) - 1} edits)")

    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    model = AutoModelForTokenClassification.from_pretrained(
        BASE_MODEL, num_labels=len(labels), id2label={i: l for l, i in labels.items()},
        label2id=labels,
    )

    # Materialize the dataset: corrupted sentence in, per-word labels out.
    examples = []
    for row in rows:
        words = row["corrupted"].split()
        label_ids = row_to_labels(row, words, labels)
        enc = tokenizer(
            words,
            is_split_into_words=True,
            truncation=True,
            max_length=MAX_LEN,
        )
        word_ids = enc.word_ids()
        aligned = [-100] * len(enc["input_ids"])
        for pos, wid in enumerate(word_ids):
            if wid is not None and wid < len(label_ids):
                aligned[pos] = label_ids[wid]
        enc["labels"] = aligned
        examples.append(enc)

    def collate(batch):
        import torch

        features = [{k: v for k, v in ex.items() if k != "labels"} for ex in batch]
        out = tokenizer.pad(features, padding=True, return_tensors="pt")
        max_len = out["input_ids"].shape[1]
        labels = torch.full((len(batch), max_len), -100, dtype=torch.long)
        for i, ex in enumerate(batch):
            lab = ex["labels"]
            labels[i, : len(lab)] = torch.tensor(lab, dtype=torch.long)
        out["labels"] = labels
        return out

    args = TrainingArguments(
        output_dir="/data/ckpt",
        num_train_epochs=EPOCHS,
        learning_rate=LR,
        per_device_train_batch_size=BATCH,
        logging_steps=50,
        save_strategy="no",
        report_to=[],
    )
    trainer = Trainer(model=model, args=args, train_dataset=examples, data_collator=collate)
    trainer.train()

    # Export: fp32 ONNX -> int8 dynamic quantization. Report the size
    # and hold the <200 MB gate right here.
    import torch

    model.eval()
    os.makedirs(out_path, exist_ok=True)
    onnx_path = os.path.join(out_path, "gec-tagger.onnx")
    torch.onnx.export(
        model,
        (
            torch.ones(1, 32, dtype=torch.long, device=model.device),
            torch.ones(1, 32, dtype=torch.long, device=model.device),
        ),
        onnx_path,
        input_names=["input_ids", "attention_mask"],
        output_names=["logits"],
        dynamic_axes={
            "input_ids": {0: "batch", 1: "seq"},
            "attention_mask": {0: "batch", 1: "seq"},
            "logits": {0: "batch", 1: "seq"},
        },
        opset_version=14,
        dynamo=False,
    )

    import onnxruntime as ort
    from onnxruntime.quantization import quantize_dynamic, QuantType

    int8_path = os.path.join(out_path, "gec-tagger.int8.onnx")
    quantize_dynamic(onnx_path, int8_path, weight_type=QuantType.QInt8)

    size_mb = os.path.getsize(int8_path) / (1024 * 1024)
    print(f"int8 model: {size_mb:.1f} MB (budget {SIZE_BUDGET_MB} MB)")
    assert size_mb < SIZE_BUDGET_MB, "int8 model exceeds the local-model budget"

    # The label map ships WITH the model: inference correctness depends
    # on the exact id->label ordering (Counter.most_common ties are
    # first-seen ordered; consumers must not rebuild it independently).
    with open(os.path.join(out_path, "labels.json"), "w") as fh:
        json.dump({str(i): lab for lab, i in labels.items()}, fh, indent=1)

    import os as _os

    eval_result = {}
    if _os.path.exists("/data/dev.jsonl"):
        eval_result = evaluate(model, tokenizer, labels, "/data/dev.jsonl")

    modal.Volume.from_name("kotoshu-gec-data").commit()
    return {"size_mb": round(size_mb, 1), "labels": len(labels), **eval_result}


@app.local_entrypoint()
def main(data: str, dev: str = ""):
    with modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True).batch_upload() as up:
        up.put_file(data, "injected.jsonl")
        if dev:
            up.put_file(dev, "dev.jsonl")
    result = train.remote("/data/injected.jsonl")
    print(result)
