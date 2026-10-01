"""GECToR-style training on REAL error data (FCE v2.1, public): token
tagger over distilroberta with the transform/append/delete/merge
label scheme. int8 ONNX export, <200 MB gate."""
from __future__ import annotations
import json, os
import modal

SIZE_BUDGET_MB = 200
BASE_MODEL = "distilroberta-base"
EPOCHS = 8
LR = 5e-5
BATCH = 16
MAX_LEN = 96
TOP_LABELS = 5000

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("torch", "transformers", "datasets", "onnx", "onnxruntime", "onnxscript", "accelerate")
)
app = modal.App("kotoshu-gec-gector")


@app.function(image=image, gpu="A10G", timeout=60 * 60 * 4,
              volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)})
def train(data_path: str = "/data/fce_gector.jsonl", out_path: str = "/data/gec-gector"):
    from collections import Counter
    import torch
    from transformers import AutoModelForTokenClassification, AutoTokenizer, TrainingArguments, Trainer

    rows = [json.loads(l) for l in open(data_path) if l.strip()]
    print(f"sentences: {len(rows)}")

    counts = Counter()
    for r in rows:
        counts.update(r["labels"])
    labels = {"$KEEP": 0}
    for lab, _ in counts.most_common(TOP_LABELS):
        if lab != "$KEEP":
            labels[lab] = len(labels)
    print(f"label vocab: {len(labels)} (top {TOP_LABELS}); coverage: "
          f"{sum(c for l, c in counts.items() if l in labels)/sum(counts.values()):.4f}")

    tokenizer = AutoTokenizer.from_pretrained(BASE_MODEL)
    model = AutoModelForTokenClassification.from_pretrained(
        BASE_MODEL, num_labels=len(labels), id2label={i: l for l, i in labels.items()}, label2id=labels)

    examples = []
    skipped = 0
    for r in rows:
        words = r["src_tokens"]
        word_labels = [labels.get(l, 0) for l in r["labels"]]
        enc = tokenizer(words, is_split_into_words=True, truncation=True, max_length=MAX_LEN)
        word_ids = enc.word_ids()
        aligned = [-100] * len(enc["input_ids"])
        for pos, wid in enumerate(word_ids):
            if wid is not None and wid < len(word_labels):
                aligned[pos] = word_labels[wid]
        if len(aligned) < len(enc["input_ids"]):
            skipped += 1
            continue
        enc["labels"] = aligned
        examples.append(enc)

    def collate(batch):
        features = [{k: v for k, v in ex.items() if k != "labels"} for ex in batch]
        out = tokenizer.pad(features, padding=True, return_tensors="pt")
        max_len = out["input_ids"].shape[1]
        lab = torch.full((len(batch), max_len), -100, dtype=torch.long)
        for i, ex in enumerate(batch):
            l = ex["labels"]
            lab[i, : len(l)] = torch.tensor(l, dtype=torch.long)
        out["labels"] = lab
        return out

    # GECToR's recipe: warmup + cosine decay (their T5/BERT runs use
    # ~10% warmup); the flat 1e-4 collapsed to the majority class.
    total_steps = (len(examples) // BATCH) * EPOCHS
    args = TrainingArguments(output_dir="/data/ckpt-gector", num_train_epochs=EPOCHS,
                             learning_rate=5e-5, per_device_train_batch_size=BATCH,
                             warmup_steps=int(total_steps * 0.10),
                             lr_scheduler_type="cosine",
                             logging_steps=100, save_strategy="no", report_to=[])
    trainer = Trainer(model=model, args=args, train_dataset=examples, data_collator=collate)
    trainer.train()

    model.eval()
    os.makedirs(out_path, exist_ok=True)
    onnx_path = os.path.join(out_path, "gec-gector.onnx")
    torch.onnx.export(
        model,
        (torch.ones(1, 32, dtype=torch.long, device=model.device),
         torch.ones(1, 32, dtype=torch.long, device=model.device)),
        onnx_path,
        input_names=["input_ids", "attention_mask"], output_names=["logits"],
        dynamic_axes={"input_ids": {0: "batch", 1: "seq"}, "attention_mask": {0: "batch", 1: "seq"},
                      "logits": {0: "batch", 1: "seq"}},
        opset_version=14, dynamo=False)
    from onnxruntime.quantization import quantize_dynamic, QuantType
    int8 = os.path.join(out_path, "gec-gector.int8.onnx")
    quantize_dynamic(onnx_path, int8, weight_type=QuantType.QInt8)
    size_mb = os.path.getsize(int8) / (1024 * 1024)
    print(f"int8 model: {size_mb:.1f} MB (budget {SIZE_BUDGET_MB})")
    assert size_mb < SIZE_BUDGET_MB
    with open(os.path.join(out_path, "labels.json"), "w") as fh:
        json.dump({str(i): l for l, i in labels.items()}, fh, indent=1)
    modal.Volume.from_name("kotoshu-gec-data").commit()
    return {"size_mb": round(size_mb, 1), "labels": len(labels), "sentences": len(examples)}


@app.local_entrypoint()
def main(data: str):
    with modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True).batch_upload() as up:
        up.put_file(data, "fce_gector.jsonl")
    print(train.remote())


if __name__ == "__main__":
    main("/tmp/fce_gector.jsonl")
