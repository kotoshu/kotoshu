"""GECToR trainer for HF Jobs — vendor-neutral twin of
train_gector_deep_modal.py (same recipe: ROUNDS x (4ep uniform + 2ep
KEEP-0.5/10), differential LRs, smoothing 0.03).

Storage is all huggingface_hub, no platform volumes:
  data       -> private dataset repo (kotoshu/gec-training-private)
  checkpoints-> private model repo per run (resume-by-download)
  final model-> int8 ONNX + labels + tokenizer, uploaded on completion

Runs inside HF Jobs (HF_TOKEN provided by the environment):
  hf jobs run --flavor h100 \
    -e UV_TORCH_CUDA=cu124 \
    python:3.12 python train_gector_hf.py \
      --data data/mega_c4_distill_2646k.jsonl \
      --base-model roberta-base --rounds 3 \
      --ckpt-repo kotoshu/gec-ckpt-deep12l
"""
from __future__ import annotations
import argparse, glob, json, os, shutil

REPO_TYPE_CKPT = "model"


def hub():
    from huggingface_hub import HfApi
    return HfApi()


def fetch_data(data_path: str) -> str:
    # under Jobs the dataset repo is volume-mounted read-only
    root = os.environ.get("GEC_DATA_ROOT")
    if root:
        mounted = os.path.join(root, data_path)
        if os.path.exists(mounted):
            return mounted
    from huggingface_hub import hf_hub_download
    return hf_hub_download("kotoshu/gec-training-private", data_path,
                           repo_type="dataset", local_dir="data_in")


def fetch_latest_checkpoint(ckpt_repo: str, local: str, run_prefix: str,
                            ckpt_vol: str = "") -> str | None:
    if ckpt_vol:
        base = os.path.join(ckpt_vol, run_prefix)
        if os.path.isdir(base):
            ckpts = sorted((d for d in os.listdir(base) if d.startswith("checkpoint-")),
                           key=lambda p: int(p.rsplit("-", 1)[1]))
            if ckpts:
                return os.path.join(base, ckpts[-1])
        # hub READS are quota-free — pre-quota-wall anchors stay resumable
        return fetch_latest_checkpoint(ckpt_repo, local, run_prefix, ckpt_vol="")
    from huggingface_hub import snapshot_download
    try:
        files = hub().list_repo_files(ckpt_repo, repo_type=REPO_TYPE_CKPT)
    except Exception:
        return None
    ckpts = sorted({f.split("/")[1] for f in files
                    if f.startswith(f"{run_prefix}/checkpoint-")},
                   key=lambda p: int(p.rsplit("-", 1)[1]))
    if not ckpts:
        return None
    snapshot_download(ckpt_repo, repo_type=REPO_TYPE_CKPT,
                      allow_patterns=f"{run_prefix}/{ckpts[-1]}/*", local_dir=local)
    return os.path.join(local, run_prefix, ckpts[-1])


def push_checkpoint(ckpt_repo: str, local_dir: str, sub: str,
                    ckpt_vol: str = "") -> None:
    src = os.path.join(local_dir, sub)
    if ckpt_vol:
        # storage-quota law (2026-10-12): hub commits ~400MB trip the org
        # wall — checkpoints live on the rw bucket mount instead
        dst = os.path.join(ckpt_vol, sub)
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(src, dst)
        return
    hub().create_repo(ckpt_repo, repo_type=REPO_TYPE_CKPT, private=True, exist_ok=True)
    hub().upload_folder(folder_path=src,
                        path_in_repo=sub, repo_id=ckpt_repo, repo_type=REPO_TYPE_CKPT,
                        commit_message=f"ckpt {sub}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="data/mega_c4_distill_2646k.jsonl")
    ap.add_argument("--base-model", default="roberta-base")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--keep", type=float, default=0.5)
    ap.add_argument("--enc-lr", type=float, default=1e-5)
    ap.add_argument("--head-lr", type=float, default=1e-3)
    ap.add_argument("--grad-clip", type=float, default=1.0)
    ap.add_argument("--ckpt-repo", required=True)
    ap.add_argument("--out-repo", default="")  # empty: ckpt repo only
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--max-len", type=int, default=96)
    ap.add_argument("--top-labels", type=int, default=5000)
    ap.add_argument("--bf16", action="store_true",
                    help="mdeberta-family: fp32 forward overflows (pretrained fp16)")
    ap.add_argument("--ckpt-vol", default="",
                    help="rw bucket mount dir — checkpoints+export go here, no hub commits")
    args = ap.parse_args()

    from collections import Counter
    import torch
    from torch import nn
    from transformers import (AutoModelForTokenClassification, AutoTokenizer,
                              Trainer, TrainerCallback, TrainingArguments)

    local_ckpt = "ckpt"
    data_file = fetch_data(args.data)
    rows = [json.loads(l) for l in open(data_file) if l.strip()]
    print(f"sentences: {len(rows)}", flush=True)

    counts = Counter()
    for r in rows:
        counts.update(r["labels"])
    labels = {"$KEEP": 0}
    for lab, _ in counts.most_common(args.top_labels):
        if lab != "$KEEP":
            labels[lab] = len(labels)
    print(f"label vocab: {len(labels)}", flush=True)

    tokenizer = AutoTokenizer.from_pretrained(args.base_model)
    model = AutoModelForTokenClassification.from_pretrained(
        args.base_model, num_labels=len(labels), torch_dtype=torch.float32,
        id2label={i: l for l, i in labels.items()}, label2id=labels)

    examples = []
    for r in rows:
        words = r["src_tokens"]
        word_labels = [labels.get(l, 0) for l in r["labels"]]
        enc = tokenizer(words, is_split_into_words=True, truncation=True, max_length=args.max_len)
        aligned = [-100] * len(enc["input_ids"])
        for pos, wid in enumerate(enc.word_ids()):
            if wid is not None and wid < len(word_labels):
                aligned[pos] = word_labels[wid]
        enc["labels"] = aligned
        examples.append(enc)

    def collate(batch):
        feats = [{k: v for k, v in ex.items() if k != "labels"} for ex in batch]
        out = tokenizer.pad(feats, padding=True, return_tensors="pt")
        lab = torch.full((len(batch), out["input_ids"].shape[1]), -100, dtype=torch.long)
        for i, ex in enumerate(batch):
            lab[i, : len(ex["labels"])] = torch.tensor(ex["labels"], dtype=torch.long)
        out["labels"] = lab
        return out

    class HubCallback(TrainerCallback):
        # on_save fires at save_steps=20000 — each save is pushed to
        # the checkpoint repo directly (save_total_limit keeps one)
        def __init__(self, run_name: str):
            self.run_name = run_name

        def on_save(self, targs, state, control, **kwargs):
            # push to a FIXED remote path: per-step folders exhaust
            # private storage (136-file incident, 2026-10-07). The
            # Trainer writes checkpoint-N locally — stage it to
            # latest/ before upload (the nonexistent-path bug killed
            # the whole 2026-10-09 batch at its first save)
            src = os.path.join(local_ckpt, self.run_name, f"checkpoint-{state.global_step}")
            if args.ckpt_vol:
                dst = os.path.join(args.ckpt_vol, self.run_name, "latest")
                if os.path.isdir(src):
                    shutil.rmtree(dst, ignore_errors=True)
                    shutil.copytree(src, dst)
                return
            dst = os.path.join(local_ckpt, self.run_name, "latest")
            if os.path.isdir(src):
                shutil.rmtree(dst, ignore_errors=True)
                shutil.copytree(src, dst)
                # Intermediate saves push MODEL-ONLY: optimizer.pt is ~2-3GB
                # and hub commit history retains every stale version — the
                # quota kills (#3/#4, 2026-10-29) came from exactly this.
                # Resume from an intermediate save restarts the stage with
                # the model weights; the FINAL push keeps everything.
                for f in ("optimizer.pt", "scheduler.pt", "rng_state.pth"):
                    fp = os.path.join(dst, f)
                    if os.path.exists(fp):
                        os.remove(fp)
                push_checkpoint(args.ckpt_repo, local_ckpt, f"{self.run_name}/latest")

    class GecTrainer(Trainer):
        keep_weight = 1.0

        def compute_loss(self, model, inputs, return_outputs=False, **kwargs):
            outputs = model(**inputs)
            weight = torch.ones(model.config.num_labels, device=outputs.logits.device)
            weight[0] = self.keep_weight
            loss = nn.functional.cross_entropy(
                outputs.logits.view(-1, model.config.num_labels),
                inputs["labels"].view(-1), weight=weight,
                label_smoothing=0.03, ignore_index=-100)
            return (loss, outputs) if return_outputs else loss

    for rnd in range(1, args.rounds + 1):
        enc_lr, head_lr = args.enc_lr / (5 ** (rnd - 1)), args.head_lr / (5 ** (rnd - 1))
        for stage, (epochs, weighted) in enumerate([(4, False), (2, True)], 1):
            run_name = f"r{rnd}s{stage}"
            ckpt_dir = os.path.join(local_ckpt, run_name)
            resume = fetch_latest_checkpoint(args.ckpt_repo, local_ckpt,
                                             f"r{rnd}s{stage}", ckpt_vol=args.ckpt_vol)
            total_steps = (len(examples) // args.batch) * epochs
            targs = TrainingArguments(output_dir=ckpt_dir, num_train_epochs=epochs,
                                      learning_rate=head_lr,
                                      per_device_train_batch_size=args.batch,
                                      warmup_steps=int(total_steps * 0.10),
                                      lr_scheduler_type="cosine", logging_steps=100,
                                      max_grad_norm=args.grad_clip,
                                      save_strategy="steps", save_steps=20000,
                                      save_total_limit=1, report_to=[],
                                      save_only_model=True,  # private-storage law: 1/3 size
                                      bf16=args.bf16)
            head = [p for n, p in model.named_parameters() if "classifier" in n]
            body = [p for n, p in model.named_parameters() if "classifier" not in n]
            opt = torch.optim.AdamW([
                {"params": body, "lr": enc_lr},
                {"params": head, "lr": head_lr},
            ], weight_decay=0.01)
            trainer = GecTrainer(model=model, args=targs, train_dataset=examples,
                                 data_collator=collate,
                                 callbacks=[HubCallback(run_name)],
                                 optimizers=(opt, None))
            trainer.keep_weight = args.keep if weighted else 1.0
            print(f"round {rnd} stage {stage}: {epochs}ep enc {enc_lr} head {head_lr} "
                  f"resume {resume}", flush=True)
            trainer.train(resume_from_checkpoint=resume)
            push_checkpoint(args.ckpt_repo, local_ckpt, run_name, ckpt_vol=args.ckpt_vol)

    model.eval()
    os.makedirs("export", exist_ok=True)
    onnx_path = "export/gec-gector.onnx"
    torch.onnx.export(
        model,
        (torch.ones(1, 32, dtype=torch.long, device=model.device),
         torch.ones(1, 32, dtype=torch.long, device=model.device)),
        onnx_path, input_names=["input_ids", "attention_mask"], output_names=["logits"],
        dynamic_axes={"input_ids": {0: "batch", 1: "seq"},
                      "attention_mask": {0: "batch", 1: "seq"},
                      "logits": {0: "batch", 1: "seq"}},
        opset_version=14, dynamo=False)
    from onnxruntime.quantization import quantize_dynamic, QuantType
    int8 = "export/gec-tagger.int8.onnx"
    try:
        quantize_dynamic(onnx_path, int8, weight_type=QuantType.QInt8)
    except Exception as exc:  # noqa: BLE001 - "scale issue" asserts on some ops
        print(f"QInt8 failed ({exc}); retrying QUInt8", flush=True)
        quantize_dynamic(onnx_path, int8, weight_type=QuantType.QUInt8)
    json.dump({str(i): l for l, i in labels.items()},
              open("export/labels.json", "w"), indent=1)
    # roberta-family: vocab_files_names keys are vocab_file/merges_file —
    # init_kwargs lookup silently misses and decodes die on ENOENT
    vfn = getattr(tokenizer, "vocab_files_names", {}) or {}
    for canon, key in (("vocab.json", "vocab_file"), ("merges.txt", "merges_file")):
        src = vfn.get(key)
        if src and os.path.exists(src):
            shutil.copy(src, f"export/{canon}")
    out_repo = args.out_repo or args.ckpt_repo
    if args.ckpt_vol:
        os.makedirs(os.path.join(args.ckpt_vol, "export"), exist_ok=True)
        for f in ("gec-tagger.int8.onnx", "labels.json", "vocab.json", "merges.txt"):
            fp = os.path.join("export", f)
            if os.path.exists(fp):
                shutil.copy(fp, os.path.join(args.ckpt_vol, "export", f))
                print(f"EXPORT TO VOLUME {f} "
                      f"{os.path.getsize(fp) / (1024 * 1024):.1f}MB", flush=True)
        return
    # export int8 + labels + tokenizer ONLY — the fp32 ONNX (0.5-1.1GB)
    # blows private storage at the final push (killed 5 runs silently)
    for f in ("gec-tagger.int8.onnx", "labels.json", "vocab.json", "merges.txt"):
        fp = os.path.join("export", f)
        if os.path.exists(fp):
            hub().upload_file(path_or_fileobj=fp, path_in_repo=f,
                              repo_id=out_repo, repo_type=REPO_TYPE_CKPT,
                              commit_message=f"export {f}")
    # VERIFY-BY-READBACK: a push that silently fails (storage wall)
    # must abort the job loudly — never report success without the
    # artifact existing remotely with the right size
    import hashlib
    from huggingface_hub import hf_hub_download as _hub_dl
    for f in ("gec-tagger.int8.onnx", "labels.json"):
        local = os.path.join("export", f)
        remote = _hub_dl(out_repo, f, repo_type=REPO_TYPE_CKPT)
        h = lambda pth: hashlib.sha256(open(pth, "rb").read()).hexdigest()[:16]
        assert h(remote) == h(local), f"EXPORT VERIFY FAILED: {f}"
        print(f"EXPORT VERIFIED {f} {os.path.getsize(local)/(1024*1024):.1f}MB", flush=True)


if __name__ == "__main__":
    main()
