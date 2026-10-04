#!/usr/bin/env python3
"""Download abstechconnect PDFs (v2).

Uses uploadedPdfs[].url (properly re-encoded: raw spaces -> %20) as the
source of truth; falls back to pdfs[]. Only downloads rows whose level is
in --levels (default undergrad 100-500). Resumable by design.

Usage: python3 abc_download_pdfs.py 100,200,300,400,500
"""
import json
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import urlsplit, quote, urlunsplit
import urllib.request

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
DETAILS = SRC / "details.jsonl"
PDF_DIR = SRC / "pdfs"
PDF_DIR.mkdir(parents=True, exist_ok=True)
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"


def encode_url(u: str) -> str:
    """Re-encode a possibly-sloppy URL path: split on /, quote each segment
    with safe chars so spaces become %20 and existing %xx stay intact."""
    p = urlsplit(u.strip())
    segs = [quote(unquote_seg, safe="") for unquote_seg in p.path.split("/")]
    # unquote then re-quote each segment to normalize double-encoding
    segs = []
    for seg in p.path.split("/"):
        # decode %xx first so %2F becomes /, then re-encode with %20 for spaces
        from urllib.parse import unquote
        segs.append(quote(unquote(seg), safe=""))
    path = "/".join(segs)
    return urlunsplit((p.scheme, p.netloc, path, p.query, ""))


def urls_of(r):
    up = r.get("uploadedPdfs") or []
    if up:
        return [u["url"] for u in up if u.get("url")]
    return [u for u in (r.get("pdfs") or []) if u]


def dl(url: str, dest: Path, tries: int = 4) -> None:
    if dest.exists() and dest.stat().st_size > 0:
        return
    url = encode_url(url)
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=120) as r, open(dest, "wb") as f:
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
    raise RuntimeError(f"download failed: {url[:120]}")


def main() -> None:
    levels = set((sys.argv[1] if len(sys.argv) > 1 else "100,200,300,400,500").split(","))
    rows = [json.loads(l) for l in DETAILS.open()]
    tasks = []
    for r in rows:
        if r["level"] not in levels:
            continue
        for i, u in enumerate(urls_of(r)):
            ext = ".pdf" if ".pdf" in u.lower() else ".bin"
            dest = PDF_DIR / f"{r['id']}-{i}{ext}"
            tasks.append((r, u, dest))

    todo = [t for t in tasks if not (t[2].exists() and t[2].stat().st_size > 0)]
    print(f"levels={sorted(levels)} files={len(tasks)} todo={len(todo)}", flush=True)

    fails = []
    n = 0
    with ThreadPoolExecutor(max_workers=6) as ex:
        futs = {ex.submit(dl, u, d): (r, u, d) for r, u, d in todo}
        for fut in as_completed(futs):
            n += 1
            r, u, d = futs[fut]
            try:
                fut.result()
            except Exception as e:  # noqa: BLE001
                fails.append((r["id"], r["name"][:40], str(e)[:100]))
            if n % 100 == 0:
                print(f"{n}/{len(todo)} | fails={len(fails)}", flush=True)
    print(f"DONE ok={len(todo) - len(fails)} fails={len(fails)}")
    for f in fails[:20]:
        print("  FAIL", f)
    with open(SRC / "download_fails.json", "w") as f:
        json.dump(fails, f, indent=1)


if __name__ == "__main__":
    main()
