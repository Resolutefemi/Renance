#!/usr/bin/env python3
"""
Refresh data/manifest.json fingerprints from the question files.

Recomputes, per exam: questionCount, totalMarks, years, bundleSha256 and
sizeBytes from the bank's JSON on disk (resolving both the flat layout
and the WAEC/ + All_tertiary_Q/ grouped layout). Every other field
(title, category, body, durationMinutes) is preserved.

Run after ANY byte-level edit to data/questions — the study API refuses
to boot when a bundle's sha256 no longer matches the manifest.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "data"
QUESTIONS = DATA / "questions"


def load_index():
    """code -> relative path under data/questions (founder's grouped layout)."""
    idx = DATA / "questions" / "index.json"
    if idx.exists():
        return json.loads(idx.read_text(encoding="utf-8"))
    return {}


INDEX = load_index()


def bundle_path(code: str) -> Path | None:
    """Resolve a bank code to its question-JSON file.

    Primary source: data/questions/index.json (the grouped layout:
    JAMB/, NECO/, WAEC/, POST_UTME/, All_tertiary_Q/<SCHOOL>/).
    Falls back to the flat layout for local flexibility.
    """
    q = DATA / "questions"
    rel = INDEX.get(code)
    if rel:
        p = q / rel
        if p.exists():
            return p
    flat = q / f"{code}.json"
    if flat.exists():
        return flat
    m = re.fullmatch(r"waec-(.+?)-bank", code)
    if m:
        p = q / "WAEC" / f"{m.group(1)}.json"
        if p.exists():
            return p
    m = re.fullmatch(r"waec-(.+?)-theory", code)
    if m:
        p = q / "WAEC" / f"{m.group(1)}-theory.json"
        if p.exists():
            return p
    m = re.fullmatch(r"uni-([a-z0-9-]+?)-([a-z0-9]+?)-bank", code)
    if m:
        p = q / "All_tertiary_Q" / m.group(1).upper() / f"{m.group(2).upper()}.json"
        if p.exists():
            return p
    return None


def main() -> int:
    manifest_path = DATA / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    missing = []
    refreshed = 0

    for exam in manifest["exams"]:
        path = bundle_path(exam["code"])
        if path is None:
            missing.append(exam["code"])
            continue
        raw = path.read_bytes()
        bundle = json.loads(raw.decode("utf-8"))
        qs = bundle.get("questions", [])
        exam["questionCount"] = bundle.get("questionCount", len(qs))
        exam["totalMarks"] = bundle.get(
            "totalMarks", sum(int(q.get("marks", 1)) for q in qs)
        )
        years = sorted({int(q["year"]) for q in qs if q.get("year")})
        if years:
            exam["years"] = years
        elif "years" in exam:
            del exam["years"]
        exam["bundleSha256"] = hashlib.sha256(raw).hexdigest()
        exam["sizeBytes"] = len(raw)
        refreshed += 1

    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"refreshed {refreshed}/{len(manifest['exams'])} manifest entries")
    if missing:
        print("MISSING files:", ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
