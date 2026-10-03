"""GLM-5.3-Flash GEC teacher via API (z.ai / bigmodel.cn), on Modal.

The API key is read from ~/.tmp-glm-key by the LOCAL entrypoint and
passed as an encrypted call argument — never printed, never logged.

Phase 1 (bake-off arm): correct a sentence-per-line file, scored
locally with the official M2 scorer.
Phase 2 (distillation): scripts/corrupt_and_distill.py feeds this
same correct() with corrupted clean text.

Usage:
  modal run scripts/glm_teacher_modal.py --inp <sources.txt> --out <out.txt>
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import modal

# The key is read by the LOCAL entrypoint only and passed as an
# encrypted call argument; it is never printed or logged.
KEYFILE = Path.home() / ".tmp-glm-key"

app = modal.App("glm-gec-teacher")

image = modal.Image.debian_slim(python_version="3.12").pip_install("openai")

PROMPT = (
    "Correct all grammatical errors in the text below. Return ONLY the "
    "corrected text — no explanations, no quotes, no added content. "
    "If the text is already correct, return it unchanged.\n\n{text}"
)

ENDPOINTS = [
    "https://api.z.ai/api/paas/v4",
    "https://open.bigmodel.cn/api/paas/v4",
]

# Results checkpoint to the volume so long paid runs resume cleanly.
VOL = modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)


@app.function(image=image, timeout=60 * 60 * 6, volumes={"/data": VOL},
              retries=modal.Retries(max_retries=2))
def correct(sentences: list[str], api_key: str, model_id: str = "glm-5.3-flash",
            checkpoint: str = "", concurrency: int = 12) -> dict:
    from openai import OpenAI

    # probe endpoints once
    base = None
    for url in ENDPOINTS:
        try:
            c = OpenAI(base_url=url, api_key=api_key, timeout=30)
            c.chat.completions.create(
                model=model_id,
                messages=[{"role": "user", "content": PROMPT.format(text="She go home.")}],
                max_tokens=64, temperature=0.0,
            )
            base = url
            break
        except Exception as exc:  # noqa: BLE001 - probe both providers
            print(f"endpoint {url} failed: {type(exc).__name__}", flush=True)
    if base is None:
        raise RuntimeError("no GLM endpoint reachable with this key")

    client = OpenAI(base_url=base, api_key=api_key, timeout=180)
    print(f"using endpoint {base}, model {model_id}", flush=True)

    ck_path = Path("/data") / checkpoint if checkpoint else None
    results: dict[int, str] = {}
    if ck_path and ck_path.exists():
        import json as _json
        results = {int(k): v for k, v in _json.loads(ck_path.read_text()).items()}
        print(f"resuming: {len(results)} already done", flush=True)

    todo = [i for i in range(len(sentences)) if i not in results]

    def one(i: int) -> None:
        r = client.chat.completions.create(
            model=model_id,
            messages=[{"role": "user", "content": PROMPT.format(text=sentences[i])}],
            max_tokens=512, temperature=0.0,
        )
        text = (r.choices[0].message.content or "").strip()
        if "</think>" in text:
            text = text.split("</think>")[-1]
        results[i] = text.strip().strip('"')

    with ThreadPoolExecutor(max_workers=concurrency) as pool:
        for n, _ in enumerate(pool.map(one, todo), 1):
            if n % 100 == 0:
                print(f"{n}/{len(todo)}", flush=True)
                if ck_path:
                    import json as _json
                    ck_path.write_text(_json.dumps(results))
                    VOL.commit()

    if ck_path:
        import json as _json
        ck_path.write_text(_json.dumps(results))
        VOL.commit()
    ordered = [results[i] for i in range(len(sentences))]
    return {"model": model_id, "n": len(ordered), "corrected": ordered}


@app.local_entrypoint()
def main(inp: str, out: str, model: str = "glm-5.3-flash", checkpoint: str = ""):
    if not KEYFILE.exists():
        raise SystemExit(f"API key file missing: {KEYFILE}")
    api_key = KEYFILE.read_text().strip()
    sentences = [line.rstrip("\n") for line in open(inp)]
    print(f"{len(sentences)} sentences, model {model} (API)")
    result = correct.remote(sentences, api_key, model_id=model, checkpoint=checkpoint)
    with open(out, "w") as fh:
        for line in result["corrected"]:
            fh.write(line.replace("\n", " ") + "\n")
    print(f"wrote {result['n']} -> {out}")
