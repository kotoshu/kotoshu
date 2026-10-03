"""Qwen3.5 GEC teacher on Modal (transformers on H100; vLLM 0.30's
engine fails on Modal's runtime with a torch stable-ABI dispatcher
error, so this uses plain batched generate()).

Experiment A: zero-shot correction of a sentence-per-line file,
scored locally with the official M2 scorer. Experiment B (bulk
synthetic-corpus generation) reuses correct().

Usage:
  modal run scripts/qwen_teacher_modal.py --inp /tmp/conll14_sources.txt \
      --out /tmp/conll14_qwen27b.txt --model Qwen/Qwen3.5-27B
"""
import modal

app = modal.App("qwen-gec-teacher")

image = modal.Image.debian_slim(python_version="3.12").pip_install(
    "transformers", "torch", "accelerate", "sentencepiece"
)

PROMPTS = {
    "default": (
        "Correct all grammatical errors in the text below. Return ONLY the "
        "corrected text — no explanations, no quotes, no added content. "
        "If the text is already correct, return it unchanged.\n\n{text}"
    ),
    "minimal": (
        "Correct ONLY the grammatical errors in the text below, changing as "
        "few words as possible. Do not rephrase, do not improve style, do not "
        "reorder, keep the author's wording. Return ONLY the minimally "
        "corrected text — no explanations, no quotes. If the text is already "
        "grammatical, return it unchanged.\n\n{text}"
    ),
}


def _run_correction(sentences: list[str], model_id: str, batch_size: int,
                   prompt_style: str) -> dict:
    import torch
    from transformers import AutoModelForCausalLM, AutoTokenizer

    tok = AutoTokenizer.from_pretrained(model_id, padding_side="left")
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token
    model = AutoModelForCausalLM.from_pretrained(
        model_id, torch_dtype=torch.bfloat16, device_map="auto", trust_remote_code=True
    )
    model.eval()

    def build_prompt(sentence: str) -> str:
        msgs = [{"role": "user", "content": PROMPTS[prompt_style].format(text=sentence)}]
        try:
            return tok.apply_chat_template(
                msgs, tokenize=False, add_generation_prompt=True, enable_thinking=False
            )
        except Exception:
            return tok.apply_chat_template(msgs, tokenize=False, add_generation_prompt=True)

    def clean(text: str) -> str:
        # strip any <think> blocks the template may emit
        if "</think>" in text:
            text = text.split("</think>")[-1]
        return text.strip().strip('"')

    corrected = []
    for i in range(0, len(sentences), batch_size):
        batch = sentences[i : i + batch_size]
        prompts = [build_prompt(s) for s in batch]
        enc = tok(prompts, return_tensors="pt", padding=True).to("cuda")
        with torch.no_grad():
            out = model.generate(
                **enc,
                max_new_tokens=512,
                do_sample=False,
                pad_token_id=tok.pad_token_id,
            )
        for j in range(len(batch)):
            gen = out[j][enc["input_ids"].shape[1] :]
            corrected.append(clean(tok.decode(gen, skip_special_tokens=True)))
        if (i // batch_size) % 10 == 0:
            print(f"{i + len(batch)}/{len(sentences)}", flush=True)

    modal.Volume.from_name("kotoshu-gec-data").commit()
    return {"model": model_id, "n": len(corrected), "corrected": corrected}


@app.function(image=image, gpu="H100", timeout=60 * 60 * 4,
              volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)})
def correct(sentences: list[str], model_id: str, batch_size: int = 16,
            prompt_style: str = "default") -> dict:
    return _run_correction(sentences, model_id, batch_size, prompt_style)


@app.function(image=image, gpu="H100:4", timeout=60 * 60 * 4,
              volumes={"/data": modal.Volume.from_name("kotoshu-gec-data", create_if_missing=True)})
def correct_big(sentences: list[str], model_id: str, batch_size: int = 16,
                prompt_style: str = "default") -> dict:
    return _run_correction(sentences, model_id, batch_size, prompt_style)


@app.local_entrypoint()
def main(inp: str, out: str, model: str = "Qwen/Qwen3.5-27B",
         prompt_style: str = "default", gpus: str = ""):
    sentences = [line.rstrip("\n") for line in open(inp)]
    print(f"{len(sentences)} sentences, model {model}, prompt {prompt_style}, gpus {gpus or 'default'}")
    fn = correct_big if gpus else correct
    result = fn.remote(sentences, model, prompt_style=prompt_style)
    with open(out, "w") as fh:
        for line in result["corrected"]:
            fh.write(line.replace("\n", " ") + "\n")
    print(f"wrote {result['n']} -> {out}")
