#!/usr/bin/env python3
"""Repair padded hyphens in the generated notes corpus.

The first writer pass spaced every hyphen ("role - play"); the founder
rule only bans long hyphens, so legitimate compounds must keep their
single tight hyphen. Titles are re-synced verbatim from the matching
scheme of work file (the source of truth); content gets the compound
join, which is safe because the writer never uses " - " as a dash
separator (the prompt bans dashes outside compound words).
"""
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / "data" / "school-notes" / "nerdc-2025"
SCHEMES = ROOT / "data" / "school-schemes" / "nerdc-2025"

JOIN = re.compile(r"(?<=[A-Za-z0-9]) - (?=[A-Za-z0-9])")

def tighten(s):
    return JOIN.sub("-", s)

repaired = 0
for nf in sorted(NOTES.rglob("*-term*.json")):
    sf = SCHEMES / nf.relative_to(NOTES)
    note = json.loads(nf.read_text())
    scheme = json.loads(sf.read_text())
    by_week = {int(w["week"]): w["topic"] for w in scheme["weeks"]}
    changed = False
    for t in note["topics"]:
        wk = int(t["week"])
        new_title = re.sub(r"\s+", " ", by_week.get(wk, t["title"])).strip()
        new_content = tighten(re.sub(r"[ \t]+", " ", t["content"])).strip()
        if new_title != t["title"] or new_content != t["content"]:
            t["title"] = new_title
            t["content"] = new_content
            changed = True
    if changed:
        nf.write_text(json.dumps(note, indent=1) + "\n")
        repaired += 1

print(f"files repaired: {repaired}")
