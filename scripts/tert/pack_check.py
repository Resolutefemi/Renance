#!/usr/bin/env python3
"""pack_check.py — structural validator for authored discipline packs.
Usage: python3 tert/pack_check.py <pack_name>   (from /home/z/my-project/scripts)"""
import re
import sys
import importlib

BANNED = [
    "specimen", "practical work", "as mentioned above", "in conclusion",
    "in this unit we will", "definitions come first", "philosophy of",
    "half of all wrong answers", "method marks are real marks",
]
BAD_TITLE_PAT = re.compile(
    r"^(overview of|meaning, scope|key principles of|working methods in|revision focus on|"
    r"connections between|tools and techniques for|data and evidence in|measuring results in|"
    r"evaluating evidence in|applications of )", re.I)

def words(s):
    return len(s.split())

def check_text(label, s, errs, allow_markup=False):
    if "\n" in s or "\r" in s or "\t" in s:
        errs.append("%s: newline/tab" % label)
    # {S}/{t}/{T} slots and ____ blanks are engine tokens, not markup
    stripped = s.replace("{S}", "").replace("{t}", "").replace("{T}", "").replace("____", "")
    if not allow_markup and re.search(r"[*_#`~\[\]{}<>|]", stripped):
        errs.append("%s: markup char %r" % (label, s[:40]))
        return
    low = s.lower()
    for b in BANNED:
        if b in low:
            errs.append("%s: banned phrase %r" % (label, b))
    if re.search(r"[\U0001F300-\U0001FAFF\u2600-\u27BF\u2264\u2265\u00d7\u00f7\u2212]", s):
        errs.append("%s: unicode symbol" % label)

def main():
    name = sys.argv[1]
    sys.path.insert(0, "/home/z/my-project/scripts/tert")
    sys.path.insert(0, "/home/z/my-project/scripts/tert/packs")
    m = importlib.import_module(name)
    errs = []
    allow_markup = name.startswith("computing") or "web" in name or "network" in name

    sections = getattr(m, "SECTIONS", None)
    if not sections or len(sections) != 14:
        errs.append("SECTIONS must have exactly 14 entries, got %s" %
                    (len(sections) if sections else 0))
        sections = sections or []
    found = getattr(m, "FOUNDATIONS", [])
    if len(found) != 12:
        errs.append("FOUNDATIONS must have exactly 12 entries, got %d" % len(found))
    for i, f in enumerate(found):
        check_text("foundation%d" % (i + 1), f, errs, allow_markup)
        if words(f) > 14:
            errs.append("foundation%d: too long (%d words)" % (i + 1, words(f)))

    for k, sec in enumerate(sections, start=2):
        tag = "S%d" % k
        title = sec.get("title", "")
        check_text(tag + " title", title, errs, allow_markup)
        if BAD_TITLE_PAT.match(title):
            errs.append("%s: generic section title %r" % (tag, title))
        units = sec.get("units", [])
        if len(units) != 10:
            errs.append("%s: %d units (need 10)" % (tag, len(units)))
        seen = set()
        for i, u in enumerate(units):
            check_text("%s unit%d" % (tag, i + 1), u, errs, allow_markup)
            if words(u) > 13:
                errs.append("%s unit%d: too long (%d w)" % (tag, i + 1, words(u)))
            if BAD_TITLE_PAT.match(u):
                errs.append("%s unit%d: generic phrasing %r" % (tag, i + 1, u[:40]))
            key = u.lower()
            if key in seen:
                errs.append("%s unit%d duplicate" % (tag, i + 1))
            seen.add(key)
        atoms = sec.get("atoms", [])
        if len(atoms) < 10:
            errs.append("%s: %d atoms (need >= 10, one per unit)" % (tag, len(atoms)))
        for i, a in enumerate(atoms):
            check_text("%s atom%d" % (tag, i + 1), a, errs, allow_markup)
            w = words(a)
            if not (55 <= w <= 110):
                errs.append("%s atom%d: %d words (need 55-110)" % (tag, i + 1, w))
        for pool, lo in (("examples", 2), ("apps", 2), ("traps", 2)):
            p = sec.get(pool, [])
            if len(p) < lo:
                errs.append("%s: %s has %d (need >= %d)" % (tag, pool, len(p), lo))
            for i, a in enumerate(p):
                check_text("%s %s%d" % (tag, pool, i + 1), a, errs, allow_markup)
                w = words(a)
                if not (50 <= w <= 120):
                    errs.append("%s %s%d: %d words (need 50-120)" % (tag, pool, i + 1, w))
        quiz = sec.get("quiz", [])
        if len(quiz) < 22:
            errs.append("%s: quiz pool %d (need >= 22)" % (tag, len(quiz)))
        kinds = {"mcq": 0, "tf": 0, "fill": 0}
        for i, item in enumerate(quiz):
            if not (isinstance(item, tuple) and len(item) == 5):
                errs.append("%s quiz%d: not a 5-tuple" % (tag, i + 1))
                continue
            kind, stem, correct, slips, explain = item
            if kind not in kinds:
                errs.append("%s quiz%d: bad kind %r" % (tag, i + 1, kind))
                continue
            kinds[kind] += 1
            check_text("%s quiz%d stem" % (tag, i + 1), stem, errs, allow_markup)
            check_text("%s quiz%d explain" % (tag, i + 1), explain, errs, allow_markup)
            if not explain or words(explain) < 5:
                errs.append("%s quiz%d: explanation too short" % (tag, i + 1))
            if kind == "mcq":
                if not isinstance(correct, str) or not correct:
                    errs.append("%s quiz%d: bad correct" % (tag, i + 1))
                if len(slips) != 3 or not all(isinstance(s, str) and s for s in slips):
                    errs.append("%s quiz%d: need exactly 3 string slips" % (tag, i + 1))
                else:
                    vals = [correct] + list(slips)
                    if len(set(vals)) != 4:
                        errs.append("%s quiz%d: duplicate options" % (tag, i + 1))
            elif kind == "tf":
                if correct not in ("True", "False"):
                    errs.append("%s quiz%d: tf correct must be True/False" % (tag, i + 1))
                if len(slips) != 1:
                    errs.append("%s quiz%d: tf needs [opposite]" % (tag, i + 1))
            elif kind == "fill":
                if not correct or "____" not in stem:
                    errs.append("%s quiz%d: fill needs ____ in stem and a correct string" % (tag, i + 1))
        if kinds["mcq"] < 12:
            errs.append("%s: only %d mcq (need >= 12)" % (tag, kinds["mcq"]))

    if errs:
        print("PACK FAIL (%d problems):" % len(errs))
        for e in errs[:60]:
            print("  -", e)
        sys.exit(1)
    print("PACK OK:", name, "-", len(sections), "sections,",
          sum(len(s.get("quiz", [])) for s in sections), "quiz factories")

if __name__ == "__main__":
    main()
