"""GLM key health + quota-window planner — runs before EVERY dispatch.

Reads ~/.config/zai-keys.toml ([[keys]] name/value, file order). Per key:
  1. 1-token liveness probe on the lane's route (invalid/dead keys out).
  2. Z.ai monitor API quota windows: 5-hour tokens (unit 3), 7-day tokens
     (unit 6), and the per-key call limit (TIME_LIMIT unit 5, resets with
     the key's monthly cycle).

Dispatch model: keys are PARALLEL capacity, not just rotation spares —
each healthy key with window headroom can carry its own lane. Default
output names the best key; --assign N names N keys for N concurrent
lanes. Exit 1 only when fewer usable keys than requested lanes exist.

Usage:
  python3 scripts/glm_key_probe.py [--paas] [--assign N] [--max-pct P]
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
QUOTA_URL = "https://api.z.ai/api/monitor/usage/quota/limit"
MAX_PCT_DEFAULT = 80


def load_keys(path=KEYFILE):
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


def probe_live(value, paas):
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
            return 200, "OK"
    except HTTPError as e:
        detail = ""
        try:
            detail = e.read()[:200].decode(errors="replace")
        except Exception:
            pass
        if e.code == 401:
            return 401, "invalid key"
        if e.code == 429:
            return 429, "rate-limited (window exhausted)"
        if "1113" in detail:
            return e.code, "no balance (1113)"
        return e.code, detail


def quota_windows(value):
    req = Request(QUOTA_URL, headers={"Authorization": f"Bearer {value}"})
    with urlopen(req, timeout=30) as r:
        d = json.loads(r.read())
    lims = d.get("data", {}).get("limits") or d.get("limits") or []
    out = {}
    for lim in lims:
        t, u = lim.get("type"), lim.get("unit")
        if t == "TOKENS_LIMIT" and u == 3:
            out["5h_pct"] = lim.get("percentage", 0)
        elif t == "TOKENS_LIMIT" and u == 6:
            out["7d_pct"] = lim.get("percentage", 0)
        elif t == "TIME_LIMIT" and u == 5:
            rem, tot = lim.get("remaining", 0), lim.get("usage", 0) or 0
            out["calls_rem"] = rem
            out["calls_pct"] = round(100 * (1 - rem / tot), 1) if tot else 0
    return out


def main():
    args = sys.argv[1:]
    paas = "--paas" in args
    n_lanes = 1
    if "--assign" in args:
        n_lanes = int(args[args.index("--assign") + 1])
    max_pct = MAX_PCT_DEFAULT
    if "--max-pct" in args:
        max_pct = float(args[args.index("--max-pct") + 1])

    keys = load_keys()
    if not keys:
        print("no keys configured in", KEYFILE)
        return 1
    healthy = []
    for k in keys:
        status, why = probe_live(k["value"], paas)
        if status == 401 or (status != 200 and status != 429):
            print(f"{k['name']}: DEAD ({status} {why})")
            continue
        try:
            q = quota_windows(k["value"])
        except Exception as e:
            print(f"{k['name']}: live ({status}) but quota lookup failed: {str(e)[:60]}")
            q = {}
        binding = max(q.get("5h_pct", 0), q.get("7d_pct", 0), q.get("calls_pct", 0))
        has_room = binding < max_pct
        print(f"{k['name']}: live ({status}) 5h {q.get('5h_pct', '?')}% "
              f"7d {q.get('7d_pct', '?')}% calls {q.get('calls_pct', '?')}% used "
              f"{'<capacity>' if has_room else '<SATURATED>'}")
        if has_room:
            healthy.append((binding, k["name"], q))
    healthy.sort(key=lambda x: x[0])
    if len(healthy) < n_lanes:
        print(f"ONLY {len(healthy)} key(s) with headroom < {max_pct}% — "
              f"need {n_lanes} lanes: do not dispatch the full set")
        return 1
    picks = [name for _, name, _ in healthy[:n_lanes]]
    print("DISPATCH keys (lowest-usage first): " + ", ".join(
        f"{name} (binding {pct}%)" for pct, name, _ in healthy[:n_lanes]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
