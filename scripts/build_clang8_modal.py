"""Build cLang-8 (English) on Modal from the raw Lang-8 20111007-2.0
dump (google-research-datasets/clang8 pipeline, targets already on the
volume). Output: clang8_source_target_en.spacy_tokenized.tsv.

Local entrypoint uploads the raw zip + the cloned clang8 repo to the
kotoshu-gec-data volume, then runs the build in-container.
"""
import subprocess
import sys
import zipfile
from pathlib import Path

import modal

app = modal.App("clang8-build")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("absl-py>=0.12.0", "spacy==3.8.5", "tqdm>=4.60.0", "click", "typer")
    .pip_install(
        "https://github.com/explosion/spacy-models/releases/download/"
        "en_core_web_sm-3.8.0/en_core_web_sm-3.8.0.tar.gz"
    )
)


@app.function(image=image, timeout=21_600, cpu=4, memory=8192,
              volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)})
def build() -> dict:
    lang8_dir = "/data/lang8/lang-8-20111007-2.0"
    if not Path(lang8_dir).is_dir():
        with zipfile.ZipFile("/data/lang8/lang-8-20111007-2.0.zip") as zf:
            members = [m for m in zf.namelist() if not m.startswith("__MACOSX")]
            zf.extractall("/data/lang8", members=members)
    out_dir = Path("/data/clang8_repo/output_data")
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable, "prepare_clang8_dataset.py",
        f"--lang8_dir={lang8_dir}",
        "--clang8_dir=targets",
        f"--output_dir={out_dir}",
        "--languages=en",
        "--tokenize_text=True",
    ]
    print("running:", " ".join(cmd), flush=True)
    result = subprocess.run(cmd, cwd="/data/clang8_repo")
    if result.returncode != 0:
        raise RuntimeError(f"clang8 build failed: exit {result.returncode}")
    modal.Volume.from_name("kotoshu-gec-data").commit()

    out = out_dir / "clang8_source_target_en.spacy_tokenized.tsv"
    pairs = sum(1 for _ in open(out)) if out.exists() else 0
    return {"tsv": str(out), "pairs": pairs}


@app.local_entrypoint()
def main(zip_path: str = "~/Downloads/lang-8-20111007-2.0.zip"):
    zp = str(Path(zip_path).expanduser())
    try:
        with modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True).batch_upload() as up:
            up.put_file(zp, "lang8/lang-8-20111007-2.0.zip")
            up.put_directory("/tmp/clang8_repo", "/clang8_repo")
    except FileExistsError:
        print("upload skipped: files already on the volume")
    print(build.remote())
