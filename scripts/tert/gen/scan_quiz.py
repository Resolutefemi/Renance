#!/usr/bin/env python3
"""Scan pack quiz pools for banned chars: --, tag-like <, non-ascii."""
import glob
import re
import sys

sys.path.insert(0, "/home/z/my-project/scripts")
sys.path.insert(0, "/home/z/my-project/scripts/tert")

TAG_LIKE = re.compile(r"<[a-zA-Z/!]")

total_items = 0
hits = []
for f in sorted(glob.glob("/home/z/my-project/scripts/tert/packs/*.py")):
    mod = f.replace("/", ".")[:-3].split(".")[-1]
    m = __import__("packs." + mod, fromlist=["SECTIONS"])
    for si, s in enumerate(getattr(m, "SECTIONS", []), 2):
        for qi, q in enumerate(s.get("quiz", [])):
            total_items += 1
            for x in q:
                if not isinstance(x, str):
                    continue
                if "--" in x:
                    hits.append((mod, si, qi, "DD", x[:70]))
                elif TAG_LIKE.search(x):
                    hits.append((mod, si, qi, "TAG", x[:70]))
                elif any(ord(c) > 127 for c in x):
                    hits.append((mod, si, qi, "ASCII", x[:70]))
print("quiz items scanned:", total_items, "| hits:", len(hits))
for h in hits[:30]:
    print(" ", h)
