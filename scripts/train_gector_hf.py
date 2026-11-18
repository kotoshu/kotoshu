"""GECToR trainer for HF Jobs — 2stage-proven schedule (s1 vanilla CE
4ep, s2 KEEP-weighted 2ep at LR/10; label smoothing 0.0): the 2026-10-31
matrix + restored-recipe arms isolated that smoothing>0 and s1
keep-weighting break fitting entirely under this stack.

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
import argparse, glob, json, os, shutil, time

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
    # per-run data cache: the rw /app bucket persists data_in/ across
    # fires — a stale cache served ja data to the ur-v1 run (2026-11-18)
    data_in = os.environ.get("GEC_DATA_IN", "data_in")
    return hf_hub_download("kotoshu/gec-training-private", data_path,
                           repo_type="dataset", local_dir=data_in)


def fetch_latest_checkpoint(ckpt_repo: str, local: str, run_prefix: str,
                            ckpt_vol: str = "") -> str | None:
    if ckpt_vol:
        base = os.path.join(ckpt_vol, run_prefix)
        if os.path.isdir(base):
            ckpts = sorted((d for d in os.listdir(base) if d.startswith("checkpoint-")),
                           key=lambda p: int(p.rsplit("-", 1)[1]))
            if ckpts:
                return os.path.join(base, ckpts[-1])
            for sub in ("latest", "final"):
                if os.path.isfile(os.path.join(base, sub, "model.safetensors")):
                    return os.path.join(base, sub)
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
        # intermediate saves are staged under latest/ (HubCallback) — the
        # ko-v11 refires lost a banked 120k anchor because the fetcher
        # only knew checkpoint-N layouts
        if any(f.startswith(f"{run_prefix}/latest/") for f in files):
            snapshot_download(ckpt_repo, repo_type=REPO_TYPE_CKPT,
                              allow_patterns=f"{run_prefix}/latest/*",
                              local_dir=local)
            return os.path.join(local, run_prefix, "latest")
        # true-final weights banked by the post-stage final-save
        if any(f == f"{run_prefix}/final/model.safetensors" for f in files):
            snapshot_download(ckpt_repo, repo_type=REPO_TYPE_CKPT,
                              allow_patterns=f"{run_prefix}/final/*",
                              local_dir=local)
            return os.path.join(local, run_prefix, "final")
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
    # transient HF 5xx must not kill a multi-hour train (500 at ko-v11 s1
    # 120k/145.5k, 2026-11-16, lost the run)
    for attempt in range(6):
        try:
            hub().upload_folder(folder_path=src,
                                path_in_repo=sub, repo_id=ckpt_repo, repo_type=REPO_TYPE_CKPT,
                                commit_message=f"ckpt {sub}")
            return
        except Exception as e:
            if attempt == 5:
                raise
            print(f"push {sub} failed ({str(e)[:120]}), retry {attempt + 1}/6", flush=True)
            time.sleep(30 * (attempt + 1))


def housekeep_stage(ckpt_repo: str, run_prefix: str) -> None:
    """Storage law (2026-11-18, round 7): each banked stage must not retain
    its checkpoint-N + latest/ copies (~2x1.1GB per mdeberta stage) — the
    triple-store refills the org wall mid-wave. final/ is the resume
    anchor; the transient copies go."""
    if not ckpt_repo:
        return
    try:
        files = hub().list_repo_files(ckpt_repo, repo_type=REPO_TYPE_CKPT)
    except Exception:
        return
    doomed = set()
    for f in files:
        parts = f.split("/")
        if len(parts) >= 3 and parts[0] == run_prefix and (
                parts[1].startswith("checkpoint-") or parts[1] == "latest"):
            doomed.add(f"{run_prefix}/{parts[1]}")
    for path in sorted(doomed):
        try:
            hub().delete_folder(path_in_repo=path, repo_id=ckpt_repo,
                                repo_type=REPO_TYPE_CKPT,
                                commit_message=f"housekeep {path} (final banked)")
            print(f"housekept {path}", flush=True)
        except Exception as e:
            print(f"housekeep {path} skipped ({str(e)[:80]})", flush=True)


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
    ap.add_argument("--epochs-s1", type=int, default=4)
    ap.add_argument("--epochs-s2", type=int, default=2)
    ap.add_argument("--label-smoothing", type=float, default=0.0)
    ap.add_argument("--keep-weight-s1", type=float, default=1.0)
    ap.add_argument("--s2-lr-div", type=int, default=10,
                    help="era-recipe reproduction: pass 1 for the pre-regression same-LR stage 2")
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

    # per-run local ckpt dir: the rw /app bucket persists across fires
    # from the same directory — a shared "ckpt" let KO-era checkpoints
    # leak into ja-v12 stage-end pushes (2026-11-18)
    local_ckpt = os.environ.get("GEC_CKPT_DIR", "ckpt")
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
    print(f"label heads: {[l for l, i in sorted(labels.items(), key=lambda kv: kv[1])[:6]]}", flush=True)
    print(f"first row head: {rows[0]['src_tokens'][:6]}", flush=True)

    # transformers>=4.x hard-asserts the INSTANCE attribute for
    # roberta-family + is_split_into_words; the flag only takes effect at
    # construction (a call-site kwarg silently does nothing).
    tkw = {"add_prefix_space": True} if "roberta" in args.base_model.lower() else {}
    tokenizer = AutoTokenizer.from_pretrained(args.base_model, **tkw)
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
        # on_save fires at save_steps=max(20000, total_steps) — each save is pushed to
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
            # multi-GPU jobs wrap the model in DataParallel — the config
            # lives on .module (l4x4 Latin wave, 2026-11-18)
            core = model.module if hasattr(model, "module") else model
            num_labels = core.config.num_labels
            weight = torch.ones(num_labels, device=outputs.logits.device)
            weight[0] = self.keep_weight
            loss = nn.functional.cross_entropy(
                outputs.logits.view(-1, num_labels),
                inputs["labels"].view(-1), weight=weight,
                label_smoothing=args.label_smoothing, ignore_index=-100)
            return (loss, outputs) if return_outputs else loss

    # 2stage-proven schedule: vanilla CE in s1 (keep weight 1.0), s2 LR /10.
    # label_smoothing>0 and s1 keep-weighting UNDER this Trainer/stack break
    # fitting entirely (all arms plateau ~1.2; restored recipe fits 0.14 —
    # isolated 2026-10-31, matrix + restored-recipe arms on h200).
    for rnd in range(1, args.rounds + 1):
        for stage, (epochs, weighted) in enumerate([(args.epochs_s1, False),
                                                    (args.epochs_s2, True)], 1):
            s2div = args.s2_lr_div if stage == 2 else 1
            enc_lr, head_lr = args.enc_lr / s2div, args.head_lr / s2div
            run_name = f"r{rnd}s{stage}"
            ckpt_dir = os.path.join(local_ckpt, run_name)
            resume = fetch_latest_checkpoint(args.ckpt_repo, local_ckpt,
                                             f"r{rnd}s{stage}", ckpt_vol=args.ckpt_vol)
            if resume is not None and \
                    not os.path.isfile(os.path.join(resume, "trainer_state.json")):
                # final/-only anchor (transient latest/checkpoint-N housekept):
                # the stage is COMPLETE. HF resume would crash on the missing
                # trainer_state.json (2026-11-19 refire loop, 8-cap burned) —
                # load the banked weights instead so the NEXT stage continues
                # from them, and skip.
                from safetensors.torch import load_file
                sd = load_file(os.path.join(resume, "model.safetensors"))
                model.load_state_dict(sd, strict=True)
                print(f"{run_name}: final banked (transients housekept) — "
                      f"weights loaded, stage skipped", flush=True)
                continue
            total_steps = (len(examples) // args.batch) * epochs
            targs = TrainingArguments(output_dir=ckpt_dir, num_train_epochs=epochs,
                                      learning_rate=head_lr,
                                      per_device_train_batch_size=args.batch,
                                      warmup_steps=int(total_steps * 0.10),
                                      lr_scheduler_type="cosine", logging_steps=100,
                                      max_grad_norm=args.grad_clip,
                                      save_strategy="steps",
                                      save_steps=int(os.environ.get("RESUME_SAVE_EVERY", "0"))
                                      or max(20000, total_steps),
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
            trainer.keep_weight = (args.keep if weighted else args.keep_weight_s1)
            print(f"round {rnd} stage {stage}: {epochs}ep enc {enc_lr} head {head_lr} "
                  f"resume {resume}", flush=True)
            trainer.train(resume_from_checkpoint=resume)
            # periodic saves stop at the last RESUME_SAVE_EVERY boundary;
            # bank the TRUE-final weights so packaging never sees a stale
            # latest/ (ko-v11: latest@20000 while s2 finished at 72746)
            final_dir = os.path.join(local_ckpt, run_name, "final")
            model.save_pretrained(final_dir)
            push_checkpoint(args.ckpt_repo, local_ckpt, f"{run_name}/final",
                            ckpt_vol=args.ckpt_vol)
            push_checkpoint(args.ckpt_repo, local_ckpt, run_name, ckpt_vol=args.ckpt_vol)
            housekeep_stage(args.ckpt_repo, run_name)

    model.eval()
    # ro-mount law (2026-11-19): fires with scripts:/app:ro have a ro cwd —
    # relative export/ writes must land in the rw per-run ckpt dir
    os.chdir(local_ckpt)
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
    if tkw.get("add_prefix_space"):
        # serve-side marker: ByteBpe must encode words space-prefixed
        open("export/prefix_space", "w").write("1\n")
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
        for f in ("gec-tagger.int8.onnx", "labels.json", "vocab.json", "merges.txt",
                  "prefix_space"):
            fp = os.path.join("export", f)
            if os.path.exists(fp):
                shutil.copy(fp, os.path.join(args.ckpt_vol, "export", f))
                print(f"EXPORT TO VOLUME {f} "
                      f"{os.path.getsize(fp) / (1024 * 1024):.1f}MB", flush=True)
        return
    # export int8 + labels + tokenizer ONLY — the fp32 ONNX (0.5-1.1GB)
    # blows private storage at the final push (killed 5 runs silently)
    for f in ("gec-tagger.int8.onnx", "labels.json", "vocab.json", "merges.txt",
                  "prefix_space"):
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
