#!/usr/bin/env python3
"""Fix joined-word text in question banks (wordsegment-based).

Scans All_tertiary_Q + POST_UTME banks for stems/options containing long
joined runs (no spaces), splits them with wordsegment, and preserves the
original capitalization pattern. Backs up nothing (git is the backup) but
prints a before/after sample for eyeballing.
NOTE: run with python3.13 (wordsegment installed there).
"""
import json
import re
import sys
from pathlib import Path

from wordsegment import load, segment

load()

REPO = Path("/home/z/my-project/renance")
BANKS = REPO / "data" / "questions"
JOINED = re.compile(r"[A-Za-z]{22,}")


def split_run(token: str) -> str:
    parts = segment(token.lower())
    out = []
    for p in parts:
        if not p:
            continue
        out.append(p)
    seg = " ".join(out)
    # restore ALL-CAPS style when the original was
    if token.isupper() and len(token) > 3:
        seg = seg.upper()
    elif token[:1].isupper():
        seg = seg[:1].upper() + seg[1:]
    return seg or token


def fix_text(t: str, touched: list) -> str:
    def repl(m: re.Match) -> str:
        fixed = split_run(m.group(0))
        if fixed.strip() and fixed != m.group(0):
            touched.append((m.group(0)[:40], fixed[:40]))
            return fixed
        return m.group(0)

    return JOINED.sub(repl, t)


def main() -> None:
    targets = sys.argv[1:] or None
    n_files = n_qs = 0
    samples: list = []
    for p in sorted(BANKS.rglob("*.json")):
        if p.name == "_sources.json" or "index" in p.name:
            continue
        rel = str(p.relative_to(BANKS))
        if targets and not any(t in rel for t in targets):
            continue
        try:
            d = json.loads(p.read_text())
        except Exception:  # noqa: BLE001
            continue
        changed = 0
        touched: list = []
        for q in d.get("questions", []):
            hit = False
            if q.get("stem") and JOINED.search(q["stem"]):
                q["stem"] = fix_text(q["stem"], touched)
                hit = True
            for k, v in list((q.get("options") or {}).items()):
                if v and JOINED.search(v):
                    q["options"][k] = fix_text(v, touched)
                    hit = True
            if hit:
                changed += 1
        if changed:
            d["questionCount"] = len(d["questions"])
            d["totalMarks"] = len(d["questions"])
            p.write_text(json.dumps(d, indent=1, ensure_ascii=False), encoding="utf-8")
            n_files += 1
            n_qs += changed
            samples.extend(touched[:2])
            print(f"fixed {rel}: {changed} questions", flush=True)

    print(f"\nDONE files={n_files} questions={n_qs}")
    print("samples:")
    for a, b in samples[:12]:
        print(f"  {a}  ->  {b}")


if __name__ == "__main__":
    main()
