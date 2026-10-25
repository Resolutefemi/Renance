#!/usr/bin/env python3
"""test_composer.py — build sample courses with the v2.5 composer and
check the founder band (10 notes x 150-250 words, 20 quiz) post-fill."""
import json
import sys

sys.path.insert(0, "/home/z/my-project/scripts")

from tert.build_all import build_one, load_pack
from tert.router import route

corpus = json.load(open("/home/z/my-project/content/tertiary/corpus.json"))

# sample courses from a spread of packs
want = ["computing_python", "medicine", "economics", "law", "agriculture"]
picked = {}
for c in corpus:
    pk = route(c)
    if pk in want and pk not in picked:
        picked[pk] = c
    if len(picked) == len(want):
        break

allok = True
for pk, c in picked.items():
    res = build_one(c)
    if res is None:
        print("%s: BUILD FAILED for %s" % (pk, c["title"]))
        allok = False
        continue
    ladder, blobs = res
    bad = []
    wmin, wmax, wsum, wn = 999, 0, 0, 0
    for uid, title, notes, quiz, S, kps, summary in blobs:
        if len(notes) != 10:
            bad.append("%s notes=%d" % (uid, len(notes)))
        if len(quiz) != 20:
            bad.append("%s quiz=%d" % (uid, len(quiz)))
        for n in notes:
            w = len(n["body"].split())
            wn += 1
            wsum += w
            wmin = min(wmin, w)
            wmax = max(wmax, w)
            if not 150 <= w <= 250:
                bad.append("%s/%s %dw" % (uid, n["heading"][:20], w))
            for tok in ("{S}", "{t}", "{T}", "{sec}"):
                if tok in n["body"]:
                    bad.append("%s token %s" % (uid, tok))
    print("%-18s %-38s lessons=%3d notes=%d band=%d-%d avg=%.0f bad=%d" % (
        pk, c["title"][:38], len(blobs), wn, wmin, wmax, wsum / max(wn, 1), len(bad)))
    for b in bad[:6]:
        print("   BAD:", b)
    if bad:
        allok = False
    # dump one full lesson for the eyeball test
    uid, title, notes, quiz, S, kps, summary = blobs[3]
    with open("/home/z/my-project/tool-results/sample_%s.json" % pk, "w") as f:
        json.dump({"uid": uid, "title": title, "S": S, "summary": summary,
                   "notes": notes, "quiz_count": len(quiz), "kps": kps}, f, indent=1)

print("VERDICT:", "PASS" if allok else "FAIL")
