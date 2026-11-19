"""Extract keyboard-adjacency maps from the gem's layout files
(coordinate grids → keys within Chebyshev distance 1) into a python
dict for latin_pack_build.py. One-off: emits adjacency JSON.
"""
import ast
import json
import re
import sys

LAYOUTS = {
    "tr": "/Users/mulgogi/src/kotoshu/kotoshu/lib/kotoshu/keyboard/layouts/turkish_q.rb",
    "el": "/Users/mulgogi/src/kotoshu/kotoshu/lib/kotoshu/keyboard/layouts/greek.rb",
    "uk": "/Users/mulgogi/src/kotoshu/kotoshu/lib/kotoshu/keyboard/layouts/ukrainian.rb",
    "sr": "/Users/mulgogi/src/kotoshu/kotoshu/lib/kotoshu/keyboard/layouts/serbian.rb",
}


def parse_coords(path):
    src = open(path, encoding="utf-8").read()
    coords = {}
    for m in re.finditer(r"'(.{1,3})'\s*=>\s*\[(\d+),\s*(\d+)\]", src):
        key = m.group(1)
        coords[key] = (int(m.group(2)), int(m.group(3)))
    return coords


def adjacency(coords):
    adj = {}
    letters = {k: v for k, v in coords.items() if len(k) == 1 and k.isalpha()}
    for k, (r, c) in letters.items():
        near = []
        for k2, (r2, c2) in letters.items():
            if k2 == k:
                continue
            if max(abs(r - r2), abs(c - c2)) == 1 or \
               (r == r2 and abs(c - c2) == 2 and min(c, c2) <= 2):
                near.append(k2)
        if near:
            adj[k.lower()] = "".join(sorted(k2.lower() for k2 in near))
    return adj


out = {}
for lang, path in LAYOUTS.items():
    out[lang] = adjacency(parse_coords(path))
    print(lang, len(out[lang]), "keys with neighbors")
json.dump(out, open("/Users/mulgogi/src/kotoshu/kotoshu/scripts/wave2_adjacency.json", "w"),
          ensure_ascii=False, indent=1)
print("wrote wave2_adjacency.json")
