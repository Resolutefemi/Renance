#!/usr/bin/env python3
"""
Bake the NERDC national scheme of work (every class, every subject,
every term) into the Flutter app as ONE bundled JSON asset.

Founder directive 2026-10-05: "just add the scheme of work of all
subjects to the dart code directly, no need for fetching it, it should
just be on the app itself." The syllabus tab reads this asset through
lib/nerdc_schemes.dart - zero network, works offline, instant.

Source layout (one folder per class level):
  data/school-schemes/nerdc-2025/{class}/{subject}-term{N}.json

Output (minified, short keys, read by lib/nerdc_schemes.dart):
  apps/mobile/assets/nerdc_schemes.json

Usage:  python3 scripts/bake_mobile_schemes.py   (run once per corpus
        refresh; the output is committed with the app)
"""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
DATA = REPO / "data" / "school-schemes" / "nerdc-2025"
OUT = REPO / "apps" / "mobile" / "assets" / "nerdc_schemes.json"

CLASS_ORDER = [
    "nursery-1", "nursery-2", "nursery-3",
    "primary-1", "primary-2", "primary-3", "primary-4", "primary-5", "primary-6",
    "jss-1", "jss-2", "jss-3",
    "sss-1", "sss-2", "sss-3",
]

# Display names, mirroring scripts/bake_school_corpus.py (JSS/SSS stay
# uppercase acronyms - .title() would render "Jss 1").
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


def main() -> int:
    if not DATA.is_dir():
        print(f"missing source data: {DATA}")
        return 1

    classes = []
    for folder in CLASS_ORDER:
        cdir = DATA / folder
        if not cdir.is_dir():
            print(f"  ! skip missing class folder {folder}")
            continue

        # subject slug -> {name, terms: {term:int -> weeks}}
        subjects: dict[str, dict] = {}
        for f in sorted(cdir.glob("*.json")):
            stem = f.stem  # e.g. mathematics-term1
            if "-term" not in stem:
                continue
            slug, _, tail = stem.rpartition("-term")
            try:
                term = int(tail)
            except ValueError:
                continue
            doc = json.loads(f.read_text(encoding="utf-8"))
            weeks = [
                {"w": int(w.get("week", 0)), "t": str(w.get("topic", "")).strip(),
                 "c": str(w.get("content", "")).strip()}
                for w in doc.get("weeks", [])
            ]
            subj = subjects.setdefault(slug, {"name": str(doc.get("subject", "")).strip(), "terms": {}})
            subj["terms"][term] = weeks
            if not subj["name"]:
                subj["name"] = slug.replace("-", " ").title()

        subs_out = []
        for slug, subj in sorted(subjects.items(), key=lambda kv: kv[1]["name"]):
            subs_out.append({
                "id": slug,
                "n": subj["name"],
                "t": [
                    {"t": term, "w": subj["terms"][term]}
                    for term in sorted(subj["terms"])
                ],
            })

        # The display name: the class map first, else the name carried
        # inside the scheme files, else the folder slug.
        name = CLASS_NAMES.get(folder) or folder
        if name == folder:
            for f in sorted(cdir.glob("*.json")):
                doc = json.loads(f.read_text(encoding="utf-8"))
                if doc.get("class"):
                    name = str(doc["class"])
                    break
            name = name.replace("-", " ").title()
        classes.append({"id": folder, "n": name, "s": subs_out})
        print(f"  + {name}: {len(subs_out)} subjects")

    out = {"src": "NERDC national scheme of work, 2025 compilations", "c": classes}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size / 1024:.0f} KB, {len(classes)} classes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
