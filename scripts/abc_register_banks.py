#!/usr/bin/env python3
"""Register the abstechconnect-harvest banks in data/questions/index.json and
data/manifest.json (fingerprints are then recomputed by refresh_manifest.py).

Adds entries only if missing; safe to re-run.
"""
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
IDX = REPO / "data" / "questions" / "index.json"
MANIFEST = REPO / "data" / "manifest.json"

NEW_BANKS = [
    # code, title, category, body, index_path
    ("uni-aau-gst102-bank", "AAU GST 102 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/aau/GST102.json"),
    ("uni-aau-gst101-bank", "AAU GST 101 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/aau/GST101.json"),
    ("uni-aau-ent201-bank", "AAU ENT 201 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/aau/ENT201.json"),
    ("uni-aau-ent211-bank", "AAU ENT 211 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/aau/ENT211.json"),
    ("uni-fupre-gst111-bank", "FUPRE GST 111 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/fupre/GST111.json"),
    ("uni-uniosun-mth101-bank", "UNIOSUN MTH 101 | Course Question Bank", "university", "University Modules", "All_tertiary_Q/uniosun/MTH101.json"),
]


def main() -> None:
    idx = json.loads(IDX.read_text())
    m = json.loads(MANIFEST.read_text())
    existing = {e["code"] for e in m["exams"]}

    added = 0
    for code, title, category, body, path in NEW_BANKS:
        bank_file = REPO / "data" / "questions" / path
        if not bank_file.exists():
            print(f"skip {code}: bank file missing")
            continue
        q = json.loads(bank_file.read_text())
        idx[code] = path
        if code not in existing:
            m["exams"].append({
                "code": code,
                "title": title,
                "questionCount": q["questionCount"],
                "totalMarks": q["questionCount"],
                "category": category,
                "body": body,
                "bundleSha256": "0" * 64,   # recomputed by refresh_manifest.py
                "sizeBytes": 0,
            })
            added += 1

    IDX.write_text(json.dumps(idx, indent=1, ensure_ascii=False) + "\n")
    MANIFEST.write_text(json.dumps(m, indent=1, ensure_ascii=False) + "\n")
    print(f"index entries: {len(idx)} | manifest exams: {len(m['exams'])} | added: {added}")


if __name__ == "__main__":
    main()
