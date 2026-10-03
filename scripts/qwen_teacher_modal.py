"""Qwen3.5 GEC teacher on Modal (vLLM, H100).

Experiment A: zero-shot correction of a sentence-per-line file
(official M2 scoring happens locally afterwards). Experiment B
(bulk synthetic-corpus generation) reuses the same correct() call.

Usage:
  modal run scripts/qwen_teacher_modal.py --in /tmp/conll14_sources.txt \
      --out /tmp/conll14_qwen27b.txt --model Qwen/Qwen3.5-27B-FP8
"""
import modal

app = modal.App("qwen-gec-teacher")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .pip_install("vllm==0.11.0", "transformers>=4.57")
    .pip_install("flashinfer-python", find_links="https://flashinfer.ai/whl/cu128")
)

PROMPT = (
    "Correct all grammatical errors in the text below. Return ONLY the "
    "corrected text — no explanations, no quotes, no added content. "
    "If the text is already correct, return it unchanged.\n\n{text}"
)


@app.function(image=image, gpu="H100", timeout=60 * 60 * 2,
              volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)})
def correct(sentences: list[str], model: str, max_tokens: int = 512) -> dict:
    from vllm import LLM, SamplingParams

    llm = LLM(model=model, max_model_len=4096, gpu_memory_utilization=0.90)
    params = SamplingParams(temperature=0.0, top_p=1.0, max_tokens=max_tokens)
    convs = [[{"role": "user", "content": PROMPT.format(text=s)}] for s in sentences]
    try:
        outs = llm.chat(convs, params, chat_template_kwargs={"enable_thinking": False})
    except Exception:
        outs = llm.chat(convs, params)
    corrected = [o.outputs[0].text.strip().strip('"') for o in outs]
    modal.Volume.from_name("kotoshu-gec-data").commit()
    return {"model": model, "n": len(corrected), "corrected": corrected}


@app.local_entrypoint()
def main(inp: str, out: str, model: str = "Qwen/Qwen3.5-27B-FP8"):
    sentences = [line.rstrip("\n") for line in open(inp)]
    print(f"{len(sentences)} sentences, model {model}")
    result = correct.remote(sentences, model)
    with open(out, "w") as fh:
        for line in result["corrected"]:
            fh.write(line.replace("\n", " ") + "\n")
    print(f"wrote {result['n']} -> {out}")
