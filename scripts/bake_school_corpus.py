#!/usr/bin/env python3
"""
Bake the national school corpus (schemes of work + lesson notes) into
the web static export.

Founder directive: the corpus lives in the codebase, not in Neon. The
website serves every class/subject/term file same-origin as static JSON
and the app reads the same files through the study API's corpus routes,
so no database copy is needed anywhere.

Source layout (one folder per class level):
  data/school-schemes/nerdc-2025/{class}/{subject}-term{N}.json
  data/school-notes/nerdc-2025/{class}/{subject}-term{N}.json

Output layout (minified, fetched by the browser):
  apps/web/public/school-corpus/index.json
  apps/web/public/school-corpus/schemes/{class}/{subject}-term{N}.json
  apps/web/public/school-corpus/notes/{class}/{subject}-term{N}.json

Usage:  python3 scripts/bake_school_corpus.py   (called by web_bundles.py)
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "data"
OUT = REPO / "apps" / "web" / "public" / "school-corpus"

CLASS_NAMES = {
    "nursery-1": "Nursery 1",
    "nursery-2": "Nursery 2",
    "nursery-3": "Nursery 3",
    "primary-1": "Primary 1",
    "primary-2": "Primary 2",
    "primary-3": "Primary 3",
    "primary-4": "Primary 4",
    "primary-5": "Primary 5",
    "primary-6": "Primary 6",
    "jss-1": "JSS 1",
    "jss-2": "JSS 2",
    "jss-3": "JSS 3",
    "sss-1": "SSS 1",
    "sss-2": "SSS 2",
    "sss-3": "SSS 3",
}

STAGES = [
    ("pre-primary", ("nursery-1", "nursery-2", "nursery-3")),
    ("primary", ("primary-1", "primary-2", "primary-3", "primary-4", "primary-5", "primary-6")),
    ("junior-secondary", ("jss-1", "jss-2", "jss-3")),
    ("senior-secondary", ("sss-1", "sss-2", "sss-3")),
]

STAGE_OF = {cls: stage for stage, classes in STAGES for cls in classes}
STAGE_LABEL = {
    "pre-primary": "Pre-primary (Nursery)",
    "primary": "Primary",
    "junior-secondary": "Junior Secondary",
    "senior-secondary": "Senior Secondary",
}


def title_case_subject(slug: str) -> str:
    return " ".join(word.capitalize() for word in slug.split("-"))


def collect(kind: str) -> dict:
    """kind is 'school-schemes' or 'school-notes'.

    Returns {class_slug: {subject_slug: [term, ...]}} plus the files that
    were copied, so the caller can report counts.
    """
    src_root = DATA / kind / "nerdc-2025"
    found: dict[str, dict[str, list[int]]] = {}
    if not src_root.exists():
        return found
    for class_dir in sorted(src_root.iterdir()):
        if not class_dir.is_dir() or class_dir.name not in CLASS_NAMES:
            continue
        for src in sorted(class_dir.glob("*.json")):
            if src.name == "index.json":
                continue
            stem = src.stem  # e.g. mathematics-term2
            if "-term" not in stem:
                continue
            subject, _, tail = stem.rpartition("-term")
            try:
                term = int(tail)
            except ValueError:
                continue
            dest = OUT / ("schemes" if kind == "school-schemes" else "notes") / class_dir.name / src.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            data = json.loads(src.read_text(encoding="utf-8"))
            dest.write_text(
                json.dumps(data, ensure_ascii=False, separators=(",", ":")),
                encoding="utf-8",
            )
            found.setdefault(class_dir.name, {}).setdefault(subject, [])
            if term not in found[class_dir.name][subject]:
                found[class_dir.name][subject].append(term)
    for cls in found:
        for subject in found[cls]:
            found[cls][subject].sort()
    return found


def build_index(schemes: dict, notes: dict) -> dict:
    classes = []
    for stage, class_slugs in STAGES:
        for cls in class_slugs:
            subjects: dict[str, dict] = {}
            for subject_slug in sorted(set(schemes.get(cls, {})) | set(notes.get(cls, {}))):
                subjects[subject_slug] = {
                    "name": title_case_subject(subject_slug),
                    "schemeTerms": schemes.get(cls, {}).get(subject_slug, []),
                    "noteTerms": notes.get(cls, {}).get(subject_slug, []),
                }
            if not subjects:
                continue
            classes.append(
                {
                    "id": cls,
                    "name": CLASS_NAMES[cls],
                    "stage": stage,
                    "stageLabel": STAGE_LABEL[stage],
                    "subjects": subjects,
                }
            )
    return {
        "source": "NERDC national curriculum corpus kept in the Renance codebase",
        "schemesPath": "/school-corpus/schemes/{class}/{subject}-term{N}.json",
        "notesPath": "/school-corpus/notes/{class}/{subject}-term{N}.json",
        "classes": classes,
    }


def main() -> int:
    schemes = collect("school-schemes")
    notes = collect("school-notes")
    index = build_index(schemes, notes)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    scheme_files = sum(len(terms) for subs in schemes.values() for terms in subs.values())
    note_files = sum(len(terms) for subs in notes.values() for terms in subs.values())
    classes_with_schemes = sum(1 for c in index["classes"] if any(s["schemeTerms"] for s in c["subjects"].values()))
    classes_with_notes = sum(1 for c in index["classes"] if any(s["noteTerms"] for s in c["subjects"].values()))
    print(
        f"school corpus baked: {scheme_files} scheme files across {classes_with_schemes} classes, "
        f"{note_files} note files across {classes_with_notes} classes -> {OUT}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
