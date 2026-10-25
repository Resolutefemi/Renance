#!/usr/bin/env python3
"""tert/build_course.py — build the full ladder + lessons for one course (QA tool)."""
import json
import sys

sys.path.insert(0, "/home/z/my-project/scripts")
sys.path.insert(0, "/home/z/my-project/scripts/tert")

from tert.spec import subject_phrase, title_case
from tert.router import is_poison_title
from tert import build_lesson
from packs import computing_python as cpa, computing_python_b as cpb, computing_quiz_topup as ct

SPEC = {
    "computing_python": {
        "sections": cpa.SECTIONS + cpb.SECTIONS,   # 14 sections for slots 2..15
        "foundations": cpb.FOUNDATIONS,            # 12 replacement titles for slot 1..12
        "topup": ct.TOPUP,
    },
}

SEC1_CATEGORY = "Concepts & Foundations"
CAT_POOL = ["Core Principles", "Methods & Practice", "Applications", "Theory & Principles",
            "Methods & Techniques", "Applications & Practice"]


def build_course(course):
    spec_key = SPEC and ("computing_python" if "python" in (course["title"] + course["dept_name"]).lower() else None)
    if not spec_key:
        return None
    spec = SPEC[spec_key]
    S = subject_phrase(course["title"], course["dept_name"])
    ladder, lessons = [], []
    # ---- section 1: keep real titles, replace poisoned ones
    s1_units = [u for u in course["units"] if u["sec"] == 1]
    s1_units.sort(key=lambda u: u["seq"])
    found = list(spec["foundations"])
    fi = 0
    for u in s1_units:
        title = u["title"]
        if is_poison_title(title):
            title = found[fi % len(found)]
            fi += 1
        ladder.append({"uid": u["uid"], "seq": u["seq"], "sec": 1, "title": title,
                       "cat": SEC1_CATEGORY, "replaced": title != u["title"]})
    # ---- sections 2..15
    for k, section in enumerate(spec["sections"], start=2):
        for j, ut in enumerate(section["units"], start=1):
            uid = "%s-EU%02d%02d" % (course["id"], k, j)
            # find the original unit (uid should exist; verify)
            ladder.append({"uid": uid, "seq": None, "sec": k, "title": ut,
                           "cat": CAT_POOL[(k - 2) % len(CAT_POOL)], "replaced": True})
    # resolve seq from original units
    by_uid = {u["uid"]: u for u in course["units"]}
    for row in ladder:
        if row["seq"] is None:
            o = by_uid.get(row["uid"])
            if o:
                row["seq"] = o["seq"]
            else:
                row["seq"] = None
    # ---- lessons
    for k, section in enumerate(spec["sections"], start=2):
        for j, ut in enumerate(section["units"], start=1):
            uid = "%s-EU%02d%02d" % (course["id"], k, j)
            notes = build_lesson.build_notes(uid, ut, S, section["title"], section)
            quiz = build_lesson.build_quiz(uid, section, spec["topup"].get("S%d" % k, []), ut, S)
            lessons.append({"uid": uid, "title": ut, "notes": notes, "quiz": quiz})
    return {"course": course, "S": S, "ladder": ladder, "lessons": lessons}


if __name__ == "__main__":
    corpus = json.load(open("/home/z/my-project/content/tertiary/corpus.json"))
    cid = sys.argv[1] if len(sys.argv) > 1 else "CRS-02001"
    c = next(x for x in corpus if x["id"] == cid)
    built = build_course(c)
    if not built:
        print("no specialization for", cid)
        sys.exit(1)
    print("course:", c["title"], "| subject phrase:", built["S"])
    print("ladder rows:", len(built["ladder"]), "| lessons:", len(built["lessons"]))
    print("\n--- sample lesson (section 3, unit 1):", built["lessons"][10]["title"])
    L = built["lessons"][10]
    for n in L["notes"][:3]:
        print("\n# %s\n%s" % (n["heading"], n["body"]))
    print("\n--- first 5 quiz items:")
    for q in L["quiz"][:5]:
        print(json.dumps(q, indent=1)[:400])
    # counts check
    bad_notes = [l["uid"] for l in built["lessons"] if len(l["notes"]) != 10]
    bad_quiz = [l["uid"] for l in built["lessons"] if len(l["quiz"]) != 20]
    print("\nbad note counts:", len(bad_notes), "| bad quiz counts:", len(bad_quiz))
    missing_seq = [r for r in built["ladder"] if r["seq"] is None]
    print("ladder rows without seq:", len(missing_seq))
