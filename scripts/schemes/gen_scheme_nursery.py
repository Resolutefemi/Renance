#!/usr/bin/env python3
"""gen_scheme_nursery - build the pre-primary (Nursery 1 to 3) corpus.

Reads the scheme_data_nurseryN*.py modules and writes one pourable JSON
per subject per term into data/school-schemes/nerdc-2025/nursery-{1,2,3}/
using the classbasic shape the bulk endpoint consumes:

    {"class": "Nursery 1", "subject": "Letter Work", "term": 1,
     "weeks": [{"week": 1, "topic": "...", "content": "..."}]}

The long hyphen never ships.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from scheme_data_nursery1a import NURSERY_1_A  # noqa: E402
from scheme_data_nursery1b import NURSERY_1_B  # noqa: E402
from scheme_data_nursery2a import NURSERY_2_A  # noqa: E402
from scheme_data_nursery2b import NURSERY_2_B  # noqa: E402
from scheme_data_nursery3a import NURSERY_3_A  # noqa: E402
from scheme_data_nursery3b import NURSERY_3_B  # noqa: E402

OUT = Path("/home/z/my-project/renance/data/school-schemes/nerdc-2025/nursery")

HYPHEN = re.compile(r"\s--\s|\u2014|\u2013")


def clean(text: str) -> str:
    return HYPHEN.sub(", ", text).strip()


def write_level(klass: str, data: dict, slug_dir: str) -> int:
    d = OUT / slug_dir
    d.mkdir(parents=True, exist_ok=True)
    written = 0
    files = []
    subjects = sorted(data.keys())
    for subject in subjects:
        for term, weeks in sorted(data[subject].items()):
            doc = {
                "class": klass,
                "subject": subject,
                "term": term,
                "weeks": [
                    {"week": i + 1, "topic": clean(t), "content": clean(c)}
                    for i, (t, c) in enumerate(weeks)
                ],
            }
            slug = subject.lower().replace("&", "and")
            slug = re.sub(r"[^a-z0-9]+", "-", slug).strip("-")
            f = d / f"{slug}-term{term}.json"
            f.write_text(json.dumps(doc, indent=1, ensure_ascii=False) + "\n")
            written += 1
            files.append({"subject": subject, "term": term, "file": f"{slug_dir}/{f.name}"})
    (d / "index.json").write_text(json.dumps({
        "class": klass,
        "subjects": subjects,
        "files": files,
    }, indent=1, ensure_ascii=False) + "\n")
    return written


def main() -> None:
    total = 0
    for klass, parts, slug in (
        ("Nursery 1", (NURSERY_1_A, NURSERY_1_B), "nursery-1"),
        ("Nursery 2", (NURSERY_2_A, NURSERY_2_B), "nursery-2"),
        ("Nursery 3", (NURSERY_3_A, NURSERY_3_B), "nursery-3"),
    ):
        data = {}
        for p in parts:
            data.update(p)
        total += write_level(klass, data, slug)
    print(f"wrote {total} scheme files under {OUT}")


if __name__ == "__main__":
    main()
