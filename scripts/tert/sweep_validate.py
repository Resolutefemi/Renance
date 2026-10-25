#!/usr/bin/env python3
"""sweep_validate.py — post-farm gate.

Checks every gen lesson file for all 21 packs:
- file exists for all 3,192 tasks
- validate(normalize(lesson)) passes at the 150-250 word band

Writes gen/sweep_report.json and prints a per-pack table.
Exit 0 only when every pack is complete and valid.
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.dirname(os.path.dirname(HERE)))  # scripts/ so tert is a package

from json_repair import loads_lenient  # noqa: E402
from validate_lesson import normalize, validate  # noqa: E402
from tert import build_lesson  # noqa: E402  (uses tert.build_lesson.gen_path)

GEN = "/home/z/my-project/content/tertiary/gen"
TASKS = os.path.join(GEN, "tasks.json")


def main():
    tasks = json.load(open(TASKS))
    packs = {}
    for t in tasks:
        packs.setdefault(t["pack"], []).append(t)

    report = {}
    total_missing = total_invalid = total_ok = 0
    for pk in sorted(packs):
        miss = bad = ok = 0
        bad_ids = []
        for t in packs[pk]:
            op = build_lesson.gen_path(t["pack"], t["sec_idx"], t["unit_idx"])
            if not os.path.exists(op):
                miss += 1
                continue
            try:
                lesson = json.load(open(op))
            except Exception:
                try:
                    lesson = loads_lenient(open(op).read())
                except Exception:
                    bad += 1
                    bad_ids.append(t["id"] + ":unreadable")
                    continue
            ok2, errs = validate(normalize(lesson))
            if ok2:
                ok += 1
            else:
                bad += 1
                bad_ids.append(t["id"] + ":" + "; ".join(errs[:2]))
        report[pk] = {"ok": ok, "invalid": bad, "missing": miss, "bad_ids": bad_ids[:20]}
        total_missing += miss
        total_invalid += bad
        total_ok += ok
        print("%-20s ok=%3d invalid=%2d missing=%2d" % (pk, ok, bad, miss))

    print("TOTAL ok=%d invalid=%d missing=%d" % (total_ok, total_invalid, total_missing))
    with open(os.path.join(GEN, "sweep_report.json"), "w") as f:
        json.dump(report, f, indent=1)
    sys.exit(0 if (total_missing == 0 and total_invalid == 0) else 1)


if __name__ == "__main__":
    main()
