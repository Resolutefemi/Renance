#!/usr/bin/env python3
"""Fetch /fetch-library-details for every catalog row -> pdfs manifest.

Resumable via details.jsonl (keyed by library id). Undergrad rows are
prioritised first so banking can start while the rest trickle in.
"""
import json
import time
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import urllib.request
import urllib.error

CATALOG = Path("/home/z/my-project/renance/data/src/abstechconnect/catalog.jsonl")
OUT = Path("/home/z/my-project/renance/data/src/abstechconnect/details.jsonl")
TOKEN = Path("/tmp/abc_token.txt").read_text().strip()
BASE = "https://backend.abstechconnect.com/api/v1/fetch-library-details"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
UNDERGRAD = {"100", "200", "300", "400", "500"}


def fetch_detail(lib_id: str, tries: int = 4) -> dict:
    url = f"{BASE}?libraryId={lib_id}"
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={
                "Authorization": f"Bearer {TOKEN}",
                "User-Agent": UA,
                "Accept": "application/json",
            })
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503):
                last = e
                time.sleep(2.0 * (a + 1))
                continue
            raise
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (a + 1))
    raise RuntimeError(f"{lib_id}: {last}")


def main() -> None:
    rows = [json.loads(l) for l in CATALOG.open()]
    done = set()
    if OUT.exists():
        for line in OUT.open():
            try:
                done.add(json.loads(line)["id"])
            except Exception:  # noqa: BLE001
                pass
    todo = [r for r in rows if r["id"] not in done]
    # undergrad first, then ASPIRANT, then the rest
    def prio(r):
        if r["level"] in UNDERGRAD:
            return 0
        if r["level"] == "ASPIRANT":
            return 1
        return 2
    todo.sort(key=prio)
    print(f"todo={len(todo)} done={len(done)}", flush=True)

    lock_fail = []
    out = OUT.open("a")
    n = 0
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(fetch_detail, r["id"]): r for r in todo}
        for fut in as_completed(futs):
            r = futs[fut]
            n += 1
            try:
                d = fut.result()
                rec = {
                    "id": r["id"],
                    "level": r["level"],
                    "institution": r["institution"],
                    "name": r["name"],
                    "pdfs": d.get("pdfs") or [],
                    "uploadedPdfs": [
                        {k: u.get(k) for k in ("fileName", "fileSize", "url")}
                        for u in (d.get("uploadedPdfs") or [])
                    ],
                    "quillId": d.get("quillId"),
                    "quillTutorials": len(d.get("quillTutorials") or []),
                    "type": d.get("type"),
                    "price": d.get("price"),
                    "slug": d.get("slug"),
                    "departments": d.get("departments"),
                    "semester": d.get("semester"),
                    "year": d.get("year"),
                    "libraryCategory": d.get("libraryCategory"),
                }
                out.write(json.dumps(rec) + "\n")
            except Exception as e:  # noqa: BLE001
                lock_fail.append((r["id"], str(e)[:120]))
            if n % 200 == 0:
                out.flush()
                print(f"{n}/{len(todo)} | fails={len(lock_fail)}", flush=True)
    out.close()
    print(f"DONE fetched={len(todo)-len(lock_fail)} fails={len(lock_fail)}")
    if lock_fail:
        print(lock_fail[:10])
        sys.exit(1)


if __name__ == "__main__":
    main()
