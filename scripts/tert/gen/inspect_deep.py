#!/usr/bin/env python3
"""Deep-inspect a generated lesson: print full notes, check banned words with
word boundaries, locate {S} uses, verify paragraph structure."""
import json
import re
import sys

sys.path.insert(0, "/home/z/my-project/scripts/tert/gen")
from inspect_gen import extract_content, strip_fences  # noqa: E402

BANNED = re.compile(
    r"\b(exams?|examiners?|examination|marks?|revision|WAEC|JAMB|NBTE|pass this|"
    r"to pass|score[sd]?)\b", re.I)


def main():
    path = sys.argv[1]
    c = strip_fences(extract_content(path))
    body = json.loads(c)
    notes = body["notes"]
    for i, n in enumerate(notes):
        w = len(n["body"].split())
        paras = n["body"].split("\n")
        hits = BANNED.findall(n["body"])
        smark = "{S}" if "{S}" in n["body"] else ""
        print("%2d | %4dw | %d paras | banned:%s | %s | %s" % (
            i + 1, w, len([p for p in paras if p.strip()]), hits, smark, n["heading"]))
    k = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    if 0 <= k < len(notes):
        print("\n===== NOTE %d FULL =====" % (k + 1))
        print(notes[k]["body"])
    if len(sys.argv) > 3:
        k2 = int(sys.argv[3])
        print("\n===== NOTE %d FULL =====" % (k2 + 1))
        print(notes[k2]["body"])


if __name__ == "__main__":
    main()
