"""ru v5 teacher pass on DeepSeek — HF Job edition.

State (exact/variant jsonl) lives in kotoshu/gec-training-private
(teacher/ru_v5/ds_out.jsonl), downloaded at start, uploaded every 250.
"""
import json
import os
import sys
import concurrent.futures as cf

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deepseek_bakeoff import call
from glm_teacher import PROMPTS
from huggingface_hub import HfApi, hf_hub_download

REPO = os.environ.get("HUB_SYNC_REPO", "kotoshu/gec-training-private")
CK_PATH = "teacher/ja_v2_ds/ds_out.jsonl"
api = HfApi()

LOCAL = "/root/.cache/kotoshu-gec/ja_v2_ds_out.jsonl"
os.makedirs(os.path.dirname(LOCAL), exist_ok=True)


def sync():
    api.upload_file(path_or_fileobj=LOCAL, path_in_repo=CK_PATH,
                    repo_type="dataset", repo_id=REPO,
                    commit_message="ru ds state sync")


try:
    p = hf_hub_download(REPO, CK_PATH, repo_type="dataset")
    open(LOCAL, "wb").write(open(p, "rb").read())
    print("hub state downloaded", flush=True)
except Exception as e:
    print(f"hub state fresh ({type(e).__name__})", flush=True)

c = "/d2"
done = {}
if not os.path.exists(LOCAL):
    open(LOCAL, "w").close()
for l in open(LOCAL, encoding="utf-8"):
    r = json.loads(l)
    done[r["corrupted"]] = r
print("resuming:", len(done), "done", flush=True)

recs = [json.loads(l) for l in open(c + "/teacher/ja_v2/pairs.jsonl", encoding="utf-8")]
prompt = PROMPTS["ja"]
out = open(LOCAL, "a", encoding="utf-8")


def work(p):
    if p["corrupted"] in done:
        return None
    txt, _ = call(p["corrupted"], prompt)
    return p, txt


n = hits = 0
with cf.ThreadPoolExecutor(int(os.environ.get("JA_CONC", "4"))) as ex:
    for r in ex.map(work, recs):
        if r is None:
            continue
        p, txt = r
        if txt is not None:
            out.write(json.dumps({"clean": p["clean"], "corrupted": p["corrupted"],
                                  "teacher": "deepseek-flash",
                                  "status": "exact" if txt == p["clean"] else "variant",
                                  "output": txt}, ensure_ascii=False) + "\n")
            out.flush()
            hits += txt == p["clean"]
        n += 1
        if n % 100 == 0:
            print(f"ja_ds {n}/70000: exact={hits} ({hits/n:.1%})", flush=True)
            sync()
sync()
print("JA DEEPSEEK PASS COMPLETE", flush=True)
