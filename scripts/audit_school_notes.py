#!/usr/bin/env python3
"""Audit the generated notes corpus against its scheme corpus.

Checks, for every data/school-notes/nerdc-2025 file:
- the matching scheme file exists and every scheme week is covered
- titles match the scheme topic wording (normalized compare)
- the note block carries the required section labels
- no long hyphens anywhere
- pour shape intact: class, subject, term, topics list
"""
import json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / "data" / "school-notes" / "nerdc-2025"
SCHEMES = ROOT / "data" / "school-schemes" / "nerdc-2025"
LABELS = ["Behavioural objectives:", "Introduction:", "Content:", "Class activity:", "Evaluation questions:", "Summary:"]
DASH = re.compile("[\u2010\u2012\u2013\u2014\u2015]|-{2,}")

def norm(s):
    return re.sub(r"\s+", " ", s).strip().lower()

problems = []
count = 0
for nf in sorted(NOTES.rglob("*-term*.json")):
    count += 1
    sf = SCHEMES / nf.relative_to(NOTES)
    note = json.loads(nf.read_text())
    for key in ("class", "subject", "term", "topics", "provenance"):
        if key not in note:
            problems.append(f"{nf.relative_to(NOTES)}: missing key {key}")
    if not sf.exists():
        problems.append(f"{nf.relative_to(NOTES)}: no matching scheme file")
        continue
    scheme = json.loads(sf.read_text())
    if note["class"] != scheme["class"] or note["subject"] != scheme["subject"] or note["term"] != scheme["term"]:
        problems.append(f"{nf.relative_to(NOTES)}: class/subject/term mismatch with scheme")
    by_week = {int(w["week"]): w for w in scheme["weeks"]}
    seen = set()
    for t in note["topics"]:
        wk = int(t["week"])
        if wk in seen:
            problems.append(f"{nf.relative_to(NOTES)}: duplicate week {wk}")
        seen.add(wk)
        src = by_week.get(wk)
        if not src:
            problems.append(f"{nf.relative_to(NOTES)}: week {wk} not in scheme")
            continue
        if norm(t["title"]) != norm(src["topic"]):
            problems.append(f"{nf.relative_to(NOTES)}: week {wk} title drift: {t['title']!r} vs {src['topic']!r}")
        missing = [l for l in LABELS if l not in t["content"]]
        if missing:
            problems.append(f"{nf.relative_to(NOTES)}: week {wk} missing {missing}")
        if DASH.search(t["content"]) or DASH.search(t["title"]):
            problems.append(f"{nf.relative_to(NOTES)}: week {wk} long hyphen")
    for wk in by_week:
        if wk not in seen:
            problems.append(f"{nf.relative_to(NOTES)}: scheme week {wk} not covered")

print(f"notes files audited: {count}")
print(f"problems: {len(problems)}")
for p in problems[:30]:
    print(" -", p)
sys.exit(1 if problems else 0)
