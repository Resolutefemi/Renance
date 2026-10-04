#!/usr/bin/env python3
"""Add the 10 missing post_utme-* bank entries to data/manifest.json.

The POST_UTME vault has 15 subject files but only 5 shipped manifest
exams, so /practice/post-utme/<subject>/ pillar pages deep-linked to
bundles that were never baked (reader 404). This appends the missing
entries modeled on the existing five; fingerprints (questionCount,
totalMarks, years, bundleSha256, sizeBytes) are recomputed afterwards by
scripts/refresh_manifest.py, the study API refuses to boot on drift.
"""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "data" / "manifest.json"

# slug in URL/file -> human title (matches the existing five's pattern)
SUBJECTS = {
    "biology-questions": "Biology",
    "chemistry-questions": "Chemistry",
    "civic-questions": "Civic Education",
    "commerce-questions": "Commerce",
    "crs-questions": "Christian Religious Studies",
    "economics-questions": "Economics",
    "english-questions": "English",
    "government-questions": "Government",
    "maths-questions": "Mathematics",
    "physics-questions": "Physics",
}

m = json.loads(MANIFEST.read_text(encoding="utf-8"))
existing = {e["code"] for e in m["exams"]}
added = []

# Insert right after the last existing post_utme entry: keeps the
# original exam order byte-stable so the diff shows ONLY the new rows.
last_pu = max(
    (i for i, e in enumerate(m["exams"]) if str(e.get("code", "")).startswith("post_utme-")),
    default=len(m["exams"]) - 1,
)
new_rows = []
for slug, title in SUBJECTS.items():
    code = f"post_utme-{slug}-bank"
    if code in existing:
        print(f"skip (exists) {code}")
        continue
    new_rows.append({
        "code": code,
        "title": f"Post-UTME {title} | Practice Bank",
        "questionCount": 0,        # recomputed by refresh_manifest.py
        "totalMarks": 0,
        "category": "secondary",
        "body": "POST-UTME",
        "years": [],
        "bundleSha256": "",
        "sizeBytes": 0,
    })
    added.append(code)

m["exams"][last_pu + 1:last_pu + 1] = new_rows

# Minified like the committed file (and like refresh_manifest.py now
# writes) - order preserved, only the new rows show in the diff.
MANIFEST.write_text(
    json.dumps(m, ensure_ascii=False, separators=(",", ":")) + "\n",
    encoding="utf-8",
)
print(f"added {len(added)}: {', '.join(added)}")
