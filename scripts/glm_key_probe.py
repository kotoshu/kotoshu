"""GLM key health probe — runs before EVERY teacher-lane dispatch.

Reads ~/.config/zai-keys.toml ([[keys]] name/value, rotation order = file
order), probes each configured key with a 1-token request on the lane's
route, and prints the first usable key so the dispatcher exports it.

Exit codes: 0 = at least one usable key; 1 = none usable (do not fire).

Usage:
  python3 scripts/glm_key_probe.py [--paas]
"""
import json
import os
import re
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen

KEYFILE = os.path.expanduser("~/.config/zai-keys.toml")
ANTHROPIC_ROUTE = "https://api.z.ai/api/anthropic/v1/messages"
PAAS_ROUTE = "https://api.z.ai/api/paas/v4/chat/completions"


def load_keys(path=KEYFILE):
    """Minimal strict parser for our own TOML shape: [[keys]] blocks with
    name/value lines (tomllib is 3.11+; the lane venvs span 3.10-3.12)."""
    keys = []
    cur = None
    for raw in open(path):
        line = raw.strip()
        if line == "[[keys]]":
            cur = {}
            keys.append(cur)
        elif cur is not None:
            m = re.match(r'(\w+)\s*=\s*"(.*)"', line)
            if m:
                cur[m.group(1)] = m.group(2)
    return [k for k in keys if k.get("value")]


def probe(value, paas):
    if paas:
        body = {"model": "glm-4.5-air",
                "messages": [{"role": "user", "content": "hi"}],
                "max_tokens": 1}
        url = PAAS_ROUTE
    else:
        body = {"model": "glm-5.3-flash", "max_tokens": 1,
                "messages": [{"role": "user", "content": "hi"}]}
        url = ANTHROPIC_ROUTE
    req = Request(url, data=json.dumps(body).encode(),
                  headers={"Content-Type": "application/json",
                           "Authorization": f"Bearer {value}"})
    try:
        with urlopen(req, timeout=30) as r:
            r.read()
            return r.status, "OK"
    except HTTPError as e:
        detail = ""
        try:
            detail = e.read()[:200].decode(errors="replace")
        except Exception:
            pass
        if e.code == 401:
            return 401, "invalid key"
        if e.code == 429:
            return 429, "rate-limited (usable, throttled)"
        if "1113" in detail:
            return e.code, "no balance (1113)"
        return e.code, detail


def main():
    paas = "--paas" in sys.argv
    keys = load_keys()
    if not keys:
        print("no keys configured in", KEYFILE)
        return 1
    usable = None
    for k in keys:
        status, why = probe(k["value"], paas)
        ok = status == 200 or status == 429
        print(f"{k['name']}: {status} {why}{' <- USE' if ok and usable is None else ''}")
        if ok and usable is None:
            usable = k
    if usable is None:
        print("NO USABLE KEY — do not dispatch")
        return 1
    print(f"DISPATCH with GLM_KEY={usable['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
