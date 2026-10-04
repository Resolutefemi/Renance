#!/usr/bin/env python3
"""gen_scheme_missing_levels - build the remaining class-level corpora.

Writes one pourable JSON per subject per term into
data/school-schemes/nerdc-2025/{primary-1,primary-2,primary-4,primary-5,
jss-1,jss-2,sss-1,sss-2}/ using the same classbasic shape the bulk
endpoint consumes:

    {"class": "Primary 1", "subject": "Mathematics", "term": 1,
     "weeks": [{"week": 1, "topic": "...", "content": "..."}]}

The long hyphen never ships.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from scheme_data_primary1 import PRIMARY_1  # noqa: E402
from scheme_data_primary2 import PRIMARY_2  # noqa: E402
from scheme_data_primary4 import PRIMARY_4  # noqa: E402
from scheme_data_primary5 import PRIMARY_5  # noqa: E402
from scheme_data_jss1 import JSS_1  # noqa: E402
from scheme_data_jss2 import JSS_2  # noqa: E402
from scheme_data_sss1 import SSS_1  # noqa: E402
from scheme_data_sss2 import SSS_2  # noqa: E402

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
        ("Primary 1", PRIMARY_1, "primary-1"),
        ("Primary 2", PRIMARY_2, "primary-2"),
        ("Primary 4", PRIMARY_4, "primary-4"),
        ("Primary 5", PRIMARY_5, "primary-5"),
        ("JSS 1", JSS_1, "jss-1"),
        ("JSS 2", JSS_2, "jss-2"),
        ("SSS 1", SSS_1, "sss-1"),
        ("SSS 2", SSS_2, "sss-2"),
    ):
        n = write_level(klass, data, slug)
        print(f"{klass}: {n} files")
        total += n
    print(f"total: {total} files")


if __name__ == "__main__":
    main()
