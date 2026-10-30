"""KLF orchestrator — all seven stages, laws encoded.

Stages: make-corpus | teach | verify | train | package | eval | publish

Registry-driven: segmentation dispatch, data sources, and routes come
from factory/registry/<lang>.yaml. Per-language SOTA techniques are
pluggable engines (`route: legacy_*`); the pipeline and contracts here
are shared.

Laws encoded (do not re-derive):
  - teach:    PAAS route, --paas-keyfile never displayed, ONE driver
              per checkpoint (check `pgrep -f checkpoint <lang>` first)
  - verify:   exact-restore gate, mandatory before train
  - train:    HF Jobs --timeout 24h ALWAYS · bucket --ckpt-vol ·
              single-file data mount · GEC_DATA_ROOT=/ for absolute
              data paths · smoke any trainer change first
  - package:  prune → int8 (NaN gate) → weight-truth remap → PARITY
              gate (artifact vs torch, decode-mode-matched)
  - corpora:  built artifacts get sha256 sidecars; the registry's
              `built:` block references them; local dir is a cache
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
CORP = os.environ.get("KLF_CORP", os.path.expanduser("~/.cache/kotoshu-gec/corpora"))
CKVOL = "hf://buckets/rhtse/jobs-artifacts"
BUCKET = f"{CKVOL}/gec"
JOB_BASE = ["hf", "jobs", "run", "--timeout", "24h", "-s", "HF_TOKEN",
            "-e", "GEC_DATA_ROOT=/"]  # 24h ALWAYS; absolute data paths resolve


def sh(cmd):
    print("+", " ".join(cmd), flush=True)
    return subprocess.run(cmd, check=True).returncode


def registry(lang):
    import yaml
    return yaml.safe_load(open(os.path.join(HERE, "registry", f"{lang}.yaml")))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------- segmentation (registry-dispatched) ----------

def seg_lang(lang, reg):
    base = f"{CORP}/base_{lang}.txt"
    seg = reg.get("segmentation", "whitespace")
    if seg == "zh_dag":
        tsv = f"{CORP}/base_{lang}.tsv"
        sh(["bundle", "exec", "ruby", "-Ilib", "-rkotoshu",
            "scripts/zh_segment_corpus.rb",
            os.path.expanduser("~/.cache/kotoshu-gec/cjk/zh_dict.txt"), base, tsv])
        return tsv
    if seg == "suika":
        tsv = f"{CORP}/base_{lang}.tsv"
        sh(["bundle", "exec", "ruby", "-Ilib", "scripts/ja_segment_corpus.rb", base, tsv])
        return tsv
    if seg != "whitespace":
        sys.exit(f"unknown segmentation '{seg}' for {lang} — register it in run.py")
    return base


# ---------- stages ----------

def make_corpus(lang):
    reg = registry(lang)
    tsv = seg_lang(lang, reg)
    base = tsv if reg.get("segmentation", "whitespace") != "whitespace" \
        else f"{CORP}/base_{lang}.txt"
    # base-corpus gate (the ja v1 class of poisoning: multi-sentence wiki
    # chunks + headings reached the teacher pass and burned ~70k calls)
    sh([sys.executable, os.path.join(HERE, "validate_base.py"), base,
        "--lang", lang])
    out = f"{CORP}/{lang}_corrupt_raw.jsonl"
    reg_file = os.path.join(HERE, "registry", f"{lang}.yaml")
    route = reg.get("route", "")
    if not route:
        classes = reg.get("classes", {})
        first = next(iter(classes), None)
        route = classes.get(first, {}).get("route", "") if first else ""
    if route.startswith("legacy_en"):
        sh([sys.executable, "scripts/corrupt_and_distill.py", "corrupt",
            f"{CORP}/base_{lang}.txt", out, "--rate", str(reg.get("rate", 0.8))])
    elif route == "legacy_jako":
        sh([sys.executable, "scripts/corrupt_jako.py",
            reg.get("legacy_lang", lang), tsv, out,
            "--rate", str(reg.get("rate", 0.8))])
    elif route == "legacy_multi":
        sh([sys.executable, "scripts/corrupt_multilingual.py", "corrupt",
            "--lang", reg.get("legacy_lang", lang), "--in", base,
            "--out", out, "--rate", str(reg.get("rate", 0.8))])
    else:
        sh([sys.executable, os.path.join(HERE, "corrupt.py"), reg_file, tsv, out,
            "--rate", str(reg.get("rate", 0.8))])
    # dedup extraction: raw pairs -> unique corrupted teacher input
    norm = lang.replace("-", "_").lower()
    seen = set()
    inp = f"{CORP}/{norm}_teacher_input.txt"
    with open(inp, "w") as tf:
        for line in open(out):
            c = json.loads(line)["corrupted"]
            if c not in seen:
                seen.add(c)
                tf.write(c + "\n")
    print(f"teacher input: {len(seen)} unique -> {inp}")
    digest = sha256_file(out)
    sidecar = out + ".sha256"
    open(sidecar, "w").write(f"{digest}  {os.path.basename(out)}\n")
    built = reg.setdefault("built", {})
    built["corrupt_raw"] = {"path": out, "sha256": digest,
                            "pairs": sum(1 for _ in open(out))}
    import yaml
    yaml.safe_dump(reg, open(reg_file, "w"), sort_keys=False, allow_unicode=True)
    # publish as a versioned dataset artifact (issue #251 item 5):
    # repo kotoshu/gec-corpora, path corpora/<lang>/<file>, sidecar attached
    sh(["hf", "upload", "--repo-type", "dataset", "--repo-id",
        "kotoshu/gec-corpora", out, f"corpora/{lang}/{os.path.basename(out)}",
        "--quiet"])
    sh(["hf", "upload", "--repo-type", "dataset", "--repo-id",
        "kotoshu/gec-corpora", sidecar,
        f"corpora/{lang}/{os.path.basename(sidecar)}", "--quiet"])
    url = (f"https://huggingface.co/datasets/kotoshu/gec-corpora/"
           f"blob/main/corpora/{lang}/{os.path.basename(out)}")
    built["corrupt_raw"]["artifact_url"] = url
    yaml.safe_dump(reg, open(reg_file, "w"), sort_keys=False, allow_unicode=True)
    print(f"corpus: {out} (sha256 {digest[:16]}…, pinned + published: {url})")


def teach(lang, conc="8"):
    reg = registry(lang)
    inp = f"{CORP}/{lang}_teacher_input.txt"
    out = f"{CORP}/{lang}_teacher_out.txt"
    if not os.path.exists(inp):
        sys.exit(f"{inp} missing — build it from the raw pairs (dedup) first")
    prompt = reg.get("prompt_lang", lang.split("_")[0])
    sh([sys.executable, "scripts/glm_teacher.py", inp, out,
        "--checkpoint", lang, "--lang", prompt, "--conc", conc, "--paas"])


def verify(lang):
    """Align raw pairs with teacher output 1:1, then exact-restore gate."""
    import json
    reg = registry(lang)
    norm = lang.replace("-", "_").lower()
    inp = f"{CORP}/{norm}_teacher_input.txt"
    outp = f"{CORP}/{norm}_teacher_out.txt"
    aligned = f"{CORP}/{norm}_aligned_pairs.jsonl"
    raw = {}
    for src in (f"{CORP}/{norm}_corrupt_raw.jsonl",):
        if not os.path.exists(src):
            continue
        for line in open(src):
            r = json.loads(line)
            raw.setdefault(r["corrupted"], r)
    n = miss = 0
    with open(aligned, "w") as f:
        for c in (l.rstrip("\n") for l in open(inp)):
            r = raw.get(c)
            if r is None:
                miss += 1
                continue
            # field-name normalization: CJK packs write the clean side as
            # "src"; the verify gate reads "clean" — emit both
            r.setdefault("clean", r.get("src", r.get("corrupted")))
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
            n += 1
    print(f"aligned: {n} pairs ({miss} unmatched)")
    verified = f"{CORP}/{lang}_verified.jsonl"
    sh([sys.executable, "scripts/corrupt_and_distill.py", "verify",
        aligned, outp, verified])
    sys.path.insert(0, os.path.join(REPO, "scripts"))
    from gector_prep import main as prep
    gector = f"{CORP}/{lang}_gector.jsonl"
    prep(verified, gector)
    _label_density_gate(gector)


def _label_density_gate(gector_path):
    """Hard gate on the built GECToR rows: a poisoned pack (cross-paired
    src/clean, the zh_gector_seg incident) shows up as absurd edit
    density and a $DELETE-label majority. Fail the stage before any
    train can consume it."""
    import collections
    rows = 0
    edits = 0
    labels = collections.Counter()
    for line in open(gector_path, encoding="utf-8"):
        d = json.loads(line)
        rows += 1
        for l in d["labels"]:
            if l == "$KEEP":
                continue
            edits += 1
            labels["REPLACE" if l.startswith("$REPLACE") else l.lstrip("$").split("_")[0]] += 1
    mean_edits = edits / rows if rows else 0.0
    del_share = labels["DELETE"] / max(1, sum(labels.values()))
    print(f"label-density gate: {rows} rows, {mean_edits:.2f} edits/sent, "
          f"labels {dict(labels.most_common(4))}, DELETE share {del_share:.3f}")
    if mean_edits > 5.0:
        sys.exit(f"GATE FAIL: {gector_path} mean edits/sentence {mean_edits:.2f} > 5.0")
    if del_share > 0.30:
        sys.exit(f"GATE FAIL: {gector_path} $DELETE share {del_share:.3f} > 0.30")


def _hf_job(name, bash, flavor="cpu-performance", mounts=(), image="python:3.12"):
    cmd = JOB_BASE + ["--flavor", flavor]
    for m in mounts:
        cmd += ["-v", m]
    cmd += ["--name", name, image, "bash", "-c", bash]
    print("+ hf jobs run (detached; follow with `hf jobs logs`)", flush=True)
    subprocess.Popen(cmd)


def train(lang):
    reg = registry(lang)
    data = f"{CORP}/{lang}_gector.jsonl"
    if not os.path.exists(data):
        sys.exit(f"{data} missing — run gector_prep on the verified pairs first")
    hold = os.path.expanduser(f"~/.cache/kotoshu-gec/{lang}data")
    os.makedirs(hold, exist_ok=True)
    sh(["cp", data, hold + "/"])
    enc, head = reg.get("enc_lr", "1e-5"), reg.get("head_lr", "1e-4")
    s1w = f"--keep-weight-s1 {reg['keep_s1']}" if reg.get("keep_s1") else ""
    base = reg.get("encoder", "roberta-base")
    bf16 = "--bf16" if reg.get("bf16", base.startswith(("mdeberta", "xlm"))) else ""
    mounts = [f"{hold}:/{'d2'}:ro", f"{REPO}/scripts:/app:ro"]
    bash = (f"pip install -q torch --index-url https://download.pytorch.org/whl/cu124 && "
            f"pip install -q transformers accelerate onnx onnxruntime onnxscript "
            f"sentencepiece protobuf && python /app/train_gector_hf.py "
            f"--data /d2/{os.path.basename(data)} --base-model {base} --rounds 1 "
            f"--keep {reg.get('keep', 0.8)} --enc-lr {enc} --head-lr {head} "
            f"--grad-clip 1.0 {bf16} {s1w} "
            f"--ckpt-repo {reg.get('ckpt_repo', f'kotoshu/gec-ckpt-{lang}')} "
            f"--out-repo {reg.get('ckpt_repo', f'kotoshu/gec-ckpt-{lang}')}")
    _hf_job(f"train-{lang}", bash, flavor=reg.get("flavor", "h200"), mounts=mounts)


def package(lang):
    """HUB-FLOW packaging (durability law): hub ckpt -> prune -> int8 ->
    parity gate -> upload to kotoshu/gec-artifacts (dataset repo)."""
    mounts = [f"{os.path.expanduser('~/.cache/kotoshu-gec/corpora')}:/corpora:ro",
              "hf://datasets/kotoshu/kotoshu-code:/code:ro",
              f"{REPO}/scripts:/app/scripts:ro",
              f"{HERE}:/app/factory:ro"]
    bash = ("pip install -q torch --index-url https://download.pytorch.org/whl/cpu && "
            "pip install -q transformers sentencepiece protobuf onnx onnxruntime "
            "huggingface_hub && python /app/factory/package_job.py --lang " + lang)
    _hf_job(f"package-{lang}", bash, flavor="cpu-performance", mounts=mounts)


def eval_stage(lang):
    reg = registry(lang)
    # hub-flow: the packaged model comes from kotoshu/gec-artifacts
    model_dir = "/model"
    model_mount = f"hf://datasets/kotoshu/gec-artifacts/{lang}:/model:ro"
    slices = (reg.get("eval", {}).get("slices")
              or [f"{lang}_heldout_sources.txt"])
    mounts = [f"{REPO}/lib:/app/lib:ro", f"{REPO}/scripts:/app/scripts:ro",
              model_mount, "hf://datasets/kotoshu/kotoshu-code:/code:ro"]
    if reg.get("eval", {}).get("official") or lang == "en":
        bash = ("gem install -q onnxruntime thor --no-document && ROUNDS=4 ruby -I/app/lib "
                "-rkotoshu /app/scripts/grammar_gector_decode.rb "
                f"{model_dir} /code/data/conll14_sources.txt /tmp/out.txt && "
                "apt-get update -qq && apt-get install -y -qq python3-minimal "
                "python3-pip >/dev/null 2>&1 && python3 -m pip install -q "
                "--break-system-packages numpy && python3 "
                "/code/data/m2scorer/scripts/m2scorer.py --max_unchanged_words 2 "
                "/tmp/out.txt /code/data/official-2014.combined.m2")
    else:
        steps = []
        for slc in slices:
            steps.append(
                "ROUNDS=4 ruby -I/app/lib -rkotoshu /app/scripts/grammar_gector_decode.rb "
                f"{model_dir} /code/data/{slc} /tmp/{slc}.out")
            steps.append(
                "apt-get update -qq && apt-get install -y -qq python3-minimal "
                "python3-pip >/dev/null 2>&1; python3 -m pip install -q "
                "--break-system-packages huggingface_hub 2>/dev/null; "
                "python3 -c \"from huggingface_hub import HfApi; "
                "HfApi(token=True).upload_file(path_or_fileobj='/tmp/" + slc + ".out', "
                f"path_in_repo='{lang}_{slc}_decoded.txt', repo_type='dataset', "
                "repo_id='kotoshu/kotoshu-code', commit_message='" + lang + " decode'); "
                "print('UPLOADED " + slc + "')\"")
        bash = ("gem install -q onnxruntime thor --no-document && "
                + " && ".join(steps))
    _hf_job(f"eval-{lang}", bash, mounts=mounts, image="ruby:3.4")


def publish(lang):
    """HUB-FLOW publish: copy packaged artifacts (kotoshu/gec-artifacts)
    into the public model repo kotoshu/grammar-{short}. No mounts."""
    short = lang.split("_")[0]
    repo = f"kotoshu/grammar-{short}"
    inner = f"""
from huggingface_hub import HfApi
api = HfApi()
api.create_repo({repo!r}, private=True, exist_ok=True)
for f in ('gec-tagger.int8.onnx', 'labels.json', 'pieces.json',
          'charsmap.json', 'parity.json'):
    api.copy_file(src_repo_type='dataset', src_repo_id='kotoshu/gec-artifacts',
                  src_path_in_repo='{lang}/' + f, repo_id={repo!r},
                  commit_message='v0.1.0 ' + f)
    print('published', f)
api.update_repo_settings(repo_id={repo!r}, private=False)
print('PUBLISHED')
"""
    bash = "pip install -q huggingface_hub && python3 -c " + repr(inner)
    _hf_job(f"publish-{lang}", bash, flavor="cpu-basic")


STAGES = {"make-corpus": make_corpus, "teach": teach, "verify": verify,
          "train": train, "package": package, "eval": eval_stage,
          "publish": publish}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", choices=sorted(STAGES))
    ap.add_argument("lang")
    ap.add_argument("--conc", default="8")
    a = ap.parse_args()
    kw = {"conc": a.conc} if a.stage == "teach" else {}
    STAGES[a.stage](a.lang, **kw)


if __name__ == "__main__":
    main()
