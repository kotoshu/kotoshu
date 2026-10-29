"""KLF base-corpus sanity validator (issue: ja v1 poisoning).

A base corpus is VALID only if every line is a single sentence-like
unit: no heading fragments, no multi-sentence chunks, length bounded.
Run BEFORE any corruption pass — the ja v1 failure (~70k wasted teacher
calls) was a base that this validator would have rejected.

Usage: python3 validate_base.py BASE.txt [--lang ja] [--max-fail-frac 0.02]
Exit 0 = valid, exit 1 = rejected (prints failure breakdown).
"""
from __future__ import annotations
import argparse
import re
import sys

HEADING = re.compile(r"^\s*=+.*=+\s*$")
MULTI_END = re.compile(r"[.!?。！？][^\s]")
CJK = re.compile(r"[一-鿿가-힣ぁ-ゟァ-ヿ]")


def line_ok(line: str) -> str | None:
    if HEADING.match(line):
        return "heading"
    if len(line) < 12:
        return "too_short"
    if len(line) > 400:
        return "too_long"
    ends = MULTI_END.findall(line)
    # a line with 2+ sentence-enders NOT followed by a space is an
    # unsplittable chunk (the ja v1 poisoning signature)
    if len(ends) >= 2:
        return "multi_sentence"
    if len(line) > 80 and not CJK.search(line) and line.count(" ") < 3:
        return "runon"
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("--lang", default="")
    ap.add_argument("--max-fail-frac", type=float, default=0.02)
    ap.add_argument("--clean", metavar="OUT", default="",
                    help="write the passing subset to OUT instead of gate-veto")
    a = ap.parse_args()
    kept_lines = []
    counts: dict[str, int] = {}
    total = 0
    for line in open(a.base, encoding="utf-8", errors="replace"):
        s = line.rstrip("\n")
        if not s.strip():
            continue
        total += 1
        why = line_ok(s)
        if why:
            counts[why] = counts.get(why, 0) + 1
        else:
            kept_lines.append(s)
    failed = total - len(kept_lines)
    frac = failed / max(1, total)
    print(f"{a.base}: {total} lines, {failed} failed ({frac:.1%}) {counts}")
    if a.clean:
        with open(a.clean, "w", encoding="utf-8") as out:
            for line in kept_lines:
                out.write(line + "\n")
        print(f"VALID (cleaned subset -> {a.clean})")
        return
    if frac > a.max_fail_frac:
        print("REJECTED — rerun with --clean to extract the passing subset, "
              "or rebuild the base (GOAL.md queue item 2)")
        sys.exit(1)
    print("VALID")


if __name__ == "__main__":
    main()
