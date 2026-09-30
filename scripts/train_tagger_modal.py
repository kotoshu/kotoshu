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
EPOCHS = 6
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


def build_label_vocab(rows: list[dict]) -> dict[str, int]:
    """GECToR-style labels from the injector's edits: $KEEP, $DELETE,
    $REPLACE_<tok>, $APPEND_<tok> (top-K replaces by frequency)."""
    from collections import Counter

    replaces = Counter()
    for row in rows:
        for edit in row["edits"]:
            if edit["tgt"] is None:
                replaces[f"$DELETE"] += 1
            else:
                replaces[f"$REPLACE_{edit['tgt']}"] += 1
    labels = {"$KEEP": 0}
    for label, _ in replaces.most_common(4000):
        labels[label] = len(labels)
    return labels


def row_to_labels(row: dict, word_list: list[str], labels: dict[str, int]) -> list[int]:
    """Per-word label ids: default $KEEP, edits override."""
    by_src = {edit["src_idx"]: edit for edit in row["edits"]}
    out = []
    for idx in range(len(word_list)):
        edit = by_src.get(idx)
        if edit is None:
            out.append(labels["$KEEP"])
        else:
            tgt = edit.get("tgt")
            label = "$DELETE" if tgt is None else f"$REPLACE_{tgt}"
            out.append(labels.get(label, labels["$KEEP"]))
    return out


def evaluate(model, tokenizer, labels: dict, dev_path: str):
    """Held-out accuracy on sentence-disjoint injected pairs: token
    label exact-match, and end-to-end correction (apply predicted
    REPLACE labels -> compare to clean)."""
    import torch

    model.eval()
    rows = [json.loads(l) for l in open(dev_path) if l.strip()]
    tok_correct = 0
    tok_total = 0
    sent_exact = 0
    corrected_exact = 0
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
            for idx in range(len(words)):
                tok_total += 1
                pred = pred_word.get(idx, 0)
                if pred == gold[idx]:
                    tok_correct += 1
            # end-to-end: apply predicted labels
            id2label = {i: l for l, i in labels.items()}
            out = []
            for idx in range(len(words)):
                lab = id2label.get(pred_word.get(idx, 0), "$KEEP")
                if lab.startswith("$REPLACE_"):
                    out.append(lab[len("$REPLACE_"):])
                elif lab == "$DELETE":
                    continue
                else:
                    out.append(words[idx])
            corrected = " ".join(out)
            if corrected == row["corrupted"].replace("$KEEP", "") and all(
                id2label.get(pred_word.get(i, 0), "$KEEP") == "$KEEP" for i in range(len(words))
            ):
                sent_exact += 1
            if corrected == " ".join(row["clean"].split()):
                corrected_exact += 1
    n = len(rows)
    return {
        "dev_pairs": n,
        "token_label_accuracy": round(tok_correct / max(tok_total, 1), 4),
        "sentences_all_keep_pred": round(sent_exact / n, 4),
        "end_to_end_exact_correction": round(corrected_exact / n, 4),
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
