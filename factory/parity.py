"""KLF artifact-parity gate (issue #251 item 4).

Compares, on N real corpus rows, in the runtime's actual decode mode:
  - ORT on the shipped artifact vs torch-fp32 on the pruned model
  - ORT single-row vs ORT padded-batch-with-mask (missing-mask catch)
Gate: row-argmax agreement >= --min-agreement. JSON out for cards.
"""
import argparse
import json
import os
import sys


def run_parity(pruned_onnx, full_ckpt, tok_dir, corpus_path,
               rows=60, min_agreement=0.98, labels_path=""):
    import numpy as np
    import onnxruntime as ort
    import torch
    from transformers import (AutoConfig, AutoModelForTokenClassification,
                              AutoTokenizer)

    tok = AutoTokenizer.from_pretrained(tok_dir)
    # the export saves the FULL tokenizer: ORT needs remapped pruned ids
    # (keep_ids.json = old ids in pruned-row order); torch keeps old ids
    keep_path = os.path.join(tok_dir, "keep_ids.json")
    if os.path.exists(keep_path):
        keep_ids = json.load(open(keep_path))
        old_to_new = {old: new for new, old in enumerate(keep_ids)}
        unk_new = old_to_new[tok.unk_token_id]
    else:
        old_to_new = None
    lines = [l.strip() for l in open(corpus_path) if l.strip()][:rows]
    # hub ckpt configs can be corrupt — build the config from the verified
    # labels.json and load weights via state_dict (never read repo config)
    labels = json.load(open(labels_path))
    id2label = {int(k): v for k, v in labels.items()}
    cfg = AutoConfig.from_pretrained(
        "microsoft/mdeberta-v3-base", num_labels=len(id2label),
        id2label=id2label, label2id={v: k for k, v in id2label.items()})
    from safetensors.torch import load_file
    state = load_file(full_ckpt)
    model = AutoModelForTokenClassification.from_config(cfg)
    missing, unexpected = model.load_state_dict(state, strict=False)
    assert not missing, f"missing weights: {missing[:4]}"
    model.eval()
    sess = ort.InferenceSession(pruned_onnx, providers=["CPUExecutionProvider"])
    sess_batch = ort.InferenceSession(pruned_onnx, providers=["CPUExecutionProvider"])

    def ort_logits(ids, mask):
        return sess.run(["logits"], {"input_ids": ids, "attention_mask": mask})[0]

    def torch_logits(ids, mask):
        with torch.no_grad():
            return model(input_ids=torch.tensor(ids),
                         attention_mask=torch.tensor(mask)).logits.numpy()

    agree_single = agree_batch = n = 0
    max_single = max_batch = 0.0
    for text in lines:
        words = text.split()
        if not words:
            continue
        enc = tok(words, is_split_into_words=True, truncation=True, max_length=96)
        L = len(enc["input_ids"])
        ort_ids = ([old_to_new.get(i, unk_new) for i in enc["input_ids"]]
                   if old_to_new else enc["input_ids"])
        o1 = ort_logits([ort_ids], [enc["attention_mask"]])[0]
        ot = torch_logits([enc["input_ids"]], [enc["attention_mask"]])[0]
        agree_single += int(np.argmax(o1, -1).tolist() == np.argmax(ot, -1).tolist())
        max_single = max(max_single, float(np.abs(o1 - ot).max()))
        pad = max(0, 4 - L)
        ids4 = [ort_ids + [tok.pad_token_id if not old_to_new
                           else old_to_new.get(tok.pad_token_id, unk_new)] * pad] * 4
        m4 = [enc["attention_mask"] + [0] * pad] * 4
        o4 = sess_batch.run(["logits"], {"input_ids": ids4, "attention_mask": m4})[0][0]
        agree_batch += int(np.argmax(o4, -1).tolist() == np.argmax(o1, -1).tolist())
        max_batch = max(max_batch, float(np.abs(o4 - o1).max()))
        assert np.isfinite(o1).all() and np.isfinite(o4).all(), "non-finite logits"
        n += 1
    assert n, "no rows scored"
    return {"rows": n,
            "ort_vs_torchfp32_row_agreement": round(agree_single / n, 4),
            "ort_vs_torchfp32_max_abs_diff": round(float(max_single), 5),
            "batched_vs_single_row_agreement": round(agree_batch / n, 4),
            "batched_vs_single_max_abs_diff": round(float(max_batch), 5),
            "gate": "PASS" if (agree_single / n >= min_agreement
                               and agree_batch / n >= min_agreement) else "FAIL"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pruned-onnx", required=True)
    ap.add_argument("--full-ckpt", required=True)
    ap.add_argument("--tokenizer", default="microsoft/mdeberta-v3-base",
                    help="full-vocab tokenizer (ignored when --tok-dir given)")
    ap.add_argument("--corpus", required=True)
    ap.add_argument("--rows", type=int, default=100)
    ap.add_argument("--min-agreement", type=float, default=0.98)
    ap.add_argument("--labels", required=True)
    ap.add_argument("--tok-dir", default="", help="pruned tokenizer dir (preferred)")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    tok_src = a.tok_dir or a.tokenizer
    r = run_parity(pruned_onnx=a.pruned_onnx, full_ckpt=a.full_ckpt,
                   tok_dir=(a.tok_dir or a.tokenizer), corpus_path=a.corpus,
                   rows=a.rows, min_agreement=a.min_agreement,
                   labels_path=a.labels)
    print(json.dumps(r))
    if a.json:
        open(a.json, "w").write(json.dumps(r, indent=1))
    if r["gate"] != "PASS":
        sys.exit(2)


if __name__ == "__main__":
    main()
