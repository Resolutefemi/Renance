#!/usr/bin/env python3
"""gen_scheme_secondary - build the missing-level corpora (Primary 3, Primary 6, JSS 3, SSS 3).

Reads the scheme_data_*.py modules and writes one pourable JSON per
subject per term into data/school-schemes/nerdc-2025/{primary-3,primary-6,jss-3,sss-3}/
using the classbasic shape the bulk endpoint consumes. The long hyphen
never ships.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from scheme_data_primary3 import PRIMARY_3  # noqa: E402
from scheme_data_primary6 import PRIMARY_6  # noqa: E402
from scheme_data_jss3 import JSS_3  # noqa: E402
from scheme_data_sss3 import SSS_3  # noqa: E402

OUT = Path("/home/z/my-project/renance/data/school-schemes/nerdc-2025")

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
    for klass, data, slug in (
        ("Primary 3", PRIMARY_3, "primary-3"),
        ("Primary 6", PRIMARY_6, "primary-6"),
        ("JSS 3", JSS_3, "jss-3"),
        ("SSS 3", SSS_3, "sss-3"),
    ):
        total += write_level(klass, data, slug)
    print(f"wrote {total} scheme files under {OUT}")


if __name__ == "__main__":
    main()
