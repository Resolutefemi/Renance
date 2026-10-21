#!/usr/bin/env python3
"""Enumerate the abstechconnect past-question catalog via /public-libraries.

The endpoint caps pageSize at 6, so full enumeration of 5,152 PastQuestion
libraries takes 860 pages. Saves one JSONL row per library with the fields
we need for harvesting (id, name, level, department, semester, year,
institution attribution from the student object).

Resumable: re-running skips pages already present in the JSONL.
"""
import json
import time
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import urllib.request

BASE = "https://backend.abstechconnect.com/api/v1/public-libraries"
TOKEN = Path("/tmp/abc_token.txt").read_text().strip()
CATEGORY = sys.argv[1] if len(sys.argv) > 1 else "PastQuestion"
OUT = Path(f"/home/z/my-project/renance/data/src/abstechconnect/catalog_{CATEGORY.lower()}.jsonl")
OUT.parent.mkdir(parents=True, exist_ok=True)

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"


def fetch_page(page: int, tries: int = 4):
    url = f"{BASE}?tabCategory={CATEGORY}&page={page}&pageSize=6"
    last_err = None
    for attempt in range(tries):
        try:
            req = urllib.request.Request(url, headers={
                "Authorization": f"Bearer {TOKEN}",
                "User-Agent": UA,
                "Accept": "application/json",
            })
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            last_err = e
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"page {page} failed: {last_err}")


def slim(rec: dict) -> dict:
    student = rec.get("student") or {}
    inst = None
    admin_school = student.get("userAdminSchool") or {}
    inst_obj = admin_school.get("institution") or {}
    if isinstance(inst_obj, dict) and inst_obj.get("name"):
        inst = inst_obj["name"]
    return {
        "id": rec["id"],
        "name": rec.get("name"),
        "author": rec.get("author"),
        "level": rec.get("level"),
        "departments": rec.get("departments"),
        "semester": rec.get("semester"),
        "year": rec.get("year"),
        "type": rec.get("type"),
        "price": rec.get("price"),
        "libraryCategory": rec.get("libraryCategory"),
        "cover": rec.get("coverPicture"),
        "institution": inst or student.get("institution"),
        "createdAt": rec.get("createdAt"),
        "studentName": (f"{student.get('firstName') or ''} {student.get('lastName') or ''}").strip(),
    }


def main() -> None:
    # first page to learn totals
    first = fetch_page(1)
    data = first["data"]
    total = data["totalCount"]
    pages = data["totalPages"]
    print(f"totalCount={total} totalPages={pages}")

    done_pages = set()
    seen_ids = set()
    if OUT.exists():
        with OUT.open() as f:
            for line in f:
                try:
                    seen_ids.add(json.loads(line)["id"])
                except Exception:  # noqa: BLE001
                    pass
    print(f"already have {len(seen_ids)} rows")

    # write first page's results too
    with OUT.open("a") as out:
        for rec in data["results"]:
            if rec["id"] not in seen_ids:
                out.write(json.dumps(slim(rec)) + "\n")
                seen_ids.add(rec["id"])

        todo = [p for p in range(2, pages + 1)]
        # page 1 done; process the rest with a small thread pool
        errors = []
        with ThreadPoolExecutor(max_workers=4) as ex:
            futs = {ex.submit(fetch_page, p): p for p in todo}
            for i, fut in enumerate(as_completed(futs), 1):
                p = futs[fut]
                try:
                    d = fut.result()["data"]
                    for rec in d["results"]:
                        if rec["id"] not in seen_ids:
                            out.write(json.dumps(slim(rec)) + "\n")
                            seen_ids.add(rec["id"])
                except Exception as e:  # noqa: BLE001
                    errors.append((p, str(e)))
                if i % 50 == 0:
                    print(f"{i}/{len(todo)} pages | rows={len(seen_ids)} | errors={len(errors)}", flush=True)
                    out.flush()

    print(f"DONE rows={len(seen_ids)} errors={len(errors)}")
    if errors:
        print("error pages:", errors[:10])
        sys.exit(1)


if __name__ == "__main__":
    main()
