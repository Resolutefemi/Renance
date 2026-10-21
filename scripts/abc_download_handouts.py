#!/usr/bin/env python3
"""Download abstechconnect HANDOUT pdfs (selective, size-capped).

Budget-conscious: skips giant scans (default >3MB), total budget 700MB,
resumable. Undergrad first.
"""
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlsplit, quote, unquote, urlunsplit
import urllib.request

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"          # handouts land alongside PQ pdfs (h- prefix)
H_DIR = SRC / "hpdfs"
H_DIR.mkdir(parents=True, exist_ok=True)
DETAILS = SRC / "details_handout.jsonl"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
UNDERGRAD = {"100", "200", "300", "400", "500"}
MAX_FILE_MB = 3.0
TOTAL_BUDGET = 700e6


def parse_size(s) -> float:
    if not s:
        return 0
    s = str(s).upper().replace(" ", "")
    for suf, m in {"KB": 1e3, "MB": 1e6, "GB": 1e9, "B": 1}.items():
        if s.endswith(suf):
            try:
                return float(s[:-len(suf)]) * m
            except ValueError:
                return 0
    return 0


def encode_url(u: str) -> str:
    p = urlsplit(u.strip())
    segs = [quote(unquote(seg), safe="") for seg in p.path.split("/")]
    return urlunsplit((p.scheme, p.netloc, "/".join(segs), p.query, ""))


def dl(url: str, dest: Path, tries: int = 3) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    url = encode_url(url)
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r, open(dest, "wb") as f:
                while True:
                    chunk = r.read(1 << 16)
                    if not chunk:
                        break
                    f.write(chunk)
            if dest.stat().st_size > 0:
                return
        except Exception:  # noqa: BLE001
            time.sleep(1.5 * (a + 1))
    dest.unlink(missing_ok=True)
    raise RuntimeError(f"fail {url[:90]}")


def main() -> None:
    rows = [json.loads(l) for l in DETAILS.open()]
    rows.sort(key=lambda r: (0 if r["level"] in UNDERGRAD else 1, r["id"]))
    tasks = []
    for r in rows:
        urls = r.get("pdfs") or []
        for i, u in enumerate(urls):
            sz = parse_size((r.get("sizes") or [""] * len(urls))[i]) if i < len(r.get("sizes") or []) else 0
            if sz > MAX_FILE_MB * 1e6:
                continue
            dest = H_DIR / f"h-{r['id']}-{i}.pdf"
            tasks.append((r, u, dest, sz))

    done_bytes = sum(t[2].stat().st_size for t in tasks if t[2].exists())
    print(f"eligible: {len(tasks)} files | already on disk bytes: {done_bytes/1e6:.0f}MB", flush=True)

    budget = TOTAL_BUDGET
    n_ok = n_fail = 0
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {}
        for r, u, d, sz in tasks:
            if d.exists() and d.stat().st_size > 0:
                continue
            if budget - (sz or 1e6) < 0:
                continue
            budget -= sz or 1e6
            futs[ex.submit(dl, u, d)] = (r, d)
        for fut in as_completed(futs):
            r, d = futs[fut]
            try:
                fut.result()
                n_ok += 1
            except Exception:  # noqa: BLE001
                n_fail += 1
            if (n_ok + n_fail) % 50 == 0:
                print(f"{n_ok + n_fail} | ok={n_ok} fail={n_fail}", flush=True)
    print(f"DONE ok={n_ok} fail={n_fail}")
    import subprocess
    subprocess.run(["du", "-sh", str(H_DIR)])


if __name__ == "__main__":
    main()
