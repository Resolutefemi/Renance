#!/usr/bin/env python3
"""Crawl public Google Drive folders via embeddedfolderview (simple HTML).

Recurses into subfolders, lists every file, and downloads PDFs through the
drive.usercontent.google.com endpoint (handles the confirm-token flow).
"""
import html as html_mod
import json
import re
import sys
import time
import urllib.request
from pathlib import Path

UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
OUT_ROOT = Path("/home/z/my-project/renance/data/src/gdrive")
OUT_ROOT.mkdir(parents=True, exist_ok=True)
LISTING = OUT_ROOT / "listing.jsonl"


def fetch(url: str, tries: int = 3) -> bytes:
    last = None
    for a in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                return r.read()
        except Exception as e:  # noqa: BLE001
            last = e
            time.sleep(1.5 * (a + 1))
    raise RuntimeError(f"fetch failed {url[:90]}: {last}")


def parse_folder(fid: str) -> list[dict]:
    """Parse embeddedfolderview HTML into entries."""
    url = f"https://drive.google.com/embeddedfolderview?id={fid}#list"
    h = fetch(url).decode("utf-8", "ignore")
    entries = []
    # each entry: <div class="flip-entry" id="entry-ID"> ... <a href="...folders/ID or file/d/ID"> ... <div class="flip-entry-title">NAME</div>
    blocks = re.findall(r'<div class="flip-entry" id="entry-([\w-]+)">.*?</div>\s*</div>', h, re.S)
    for m in re.finditer(
        r'<div class="flip-entry" id="entry-([\w-]+)"[^>]*>(.*?)(?=<div class="flip-entry"|$)', h, re.S
    ):
        eid, blk = m.group(1), m.group(2)
        tm = re.search(r'<div class="flip-entry-title">([^<]*)</div>', blk)
        name = html_mod.unescape(tm.group(1)).strip() if tm else "unknown"
        href = re.search(r'href="(https://drive\.google\.com/(?:drive/folders|file/d)/)', blk)
        kind = "folder" if (href and "folders" in href.group(1)) else "file"
        entries.append({"id": eid, "name": name, "kind": kind})
    return entries


def download_file(fid: str, dest: Path) -> bool:
    if dest.exists() and dest.stat().st_size > 0:
        return True
    # direct download endpoint
    url = f"https://drive.usercontent.google.com/download?id={fid}&export=download"
    try:
        data = fetch(url)
        head = data[:200].lower()
        if b"<!doctype html" in head or b"<html" in head:
            # interstitial: extract confirm + uuid form fields
            txt = data.decode("utf-8", "ignore")
            fields = dict(re.findall(r'name="([^"]+)"\s+value="([^"]*)"', txt))
            if "confirm" in fields or "uuid" in fields:
                q = f"id={fid}&export=download"
                for k in ("confirm", "uuid", "at"):
                    if k in fields:
                        q += f"&{k}={fields[k]}"
                data = fetch(f"https://drive.usercontent.google.com/download?{q}")
                head = data[:200].lower()
                if b"<html" in head:
                    return False
            else:
                return False
        if not data:
            return False
        dest.write_bytes(data)
        return dest.stat().st_size > 0
    except Exception as e:  # noqa: BLE001
        print(f"    dl fail {dest.name[:50]}: {str(e)[:60]}", flush=True)
        return False


def crawl(fid: str, path: str, seen: set, files: list, depth: int = 0) -> None:
    if fid in seen or depth > 6:
        return
    seen.add(fid)
    try:
        entries = parse_folder(fid)
    except Exception as e:  # noqa: BLE001
        print(f"  [!] folder {fid}: {str(e)[:60]}", flush=True)
        return
    for e in entries:
        full = f"{path}/{e['name']}" if path else e["name"]
        if e["kind"] == "folder":
            print(f"  {'  '*depth}[dir] {full[:70]}", flush=True)
            crawl(e["id"], full, seen, files, depth + 1)
        else:
            e["path"] = full
            files.append(e)


def main() -> None:
    roots = {
        "107Di_IC3JukvwOZmIxzO0osuhOYssp2y": "BAMBOY 100L 2nd sem",
        "1xU7h0znvGVveqV2fkhMJvxyshdn2tu3n": "Cyssa hub",
        "1_SXd5yZKSQbOGJ3I4V7rb0vHGnx_kbIi": "200L-SEN-BOOKS",
        "1DmBZh1n_j2lcXza3cc15wKFMZ7GukvBf": "2nd Semester",
    }
    files = []
    for rid, label in roots.items():
        print(f"=== {label} ({rid})", flush=True)
        crawl(rid, label, set(), files)

    print(f"\ntotal files: {len(files)}")
    with LISTING.open("w") as f:
        for e in files:
            f.write(json.dumps(e) + "\n")

    # download PDFs
    n_ok = n_fail = 0
    for e in files:
        name = e["name"]
        if not name.lower().endswith(".pdf"):
            # also check kind text? embeddedfolderview titles lack extensions sometimes
            pass
        safe = re.sub(r"[^\w\s().-]", "", e.get("path", name)).strip()[:140]
        dest = OUT_ROOT / f"{safe}.pdf"
        if download_file(e["id"], dest):
            n_ok += 1
        else:
            n_fail += 1
    print(f"downloaded: {n_ok} | failed: {n_fail}")


if __name__ == "__main__":
    main()
