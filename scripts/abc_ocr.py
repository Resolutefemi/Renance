#!/usr/bin/env python3
"""OCR the image-only abstechconnect PDFs (undergrad first).

For each target pdf: pdftoppm -r 200 gray -> tesseract --psm 4 per page ->
concatenated <stem>.ocr.txt. Skips existing outputs. Pages beyond --max-pages
are deferred (a second pass can raise the cap).

Usage: python3 abc_ocr.py [max_pages=40]
"""
import json
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
TARGETS = json.loads((SRC / "ocr_targets.json").read_text())


def page_count(pdf: Path) -> int:
    r = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True, timeout=30)
    for line in r.stdout.splitlines():
        if line.startswith("Pages:"):
            return int(line.split()[-1])
    return 1


def ocr_pdf(fname: str, max_pages: int) -> dict:
    pdf = PDF_DIR / fname
    stem = pdf.stem
    out_path = pdf.with_suffix(".ocr.txt")
    if out_path.exists() and out_path.stat().st_size > 100:
        return {"file": fname, "status": "cached", "pages": 0}
    n = page_count(pdf)
    if n > max_pages:
        return {"file": fname, "status": "deferred", "pages": n}
    with tempfile.TemporaryDirectory() as td:
        tdp = Path(td)
        r = subprocess.run(
            ["pdftoppm", "-r", "150", "-gray", "-png", str(pdf), str(tdp / "pg")],
            capture_output=True, timeout=600,
            env={"OMP_THREAD_LIMIT": "1", "PATH": "/usr/bin:/bin:/usr/local/bin"},
        )
        if r.returncode != 0:
            return {"file": fname, "status": "pdftoppm_failed", "pages": n}
        texts = []
        for png in sorted(tdp.glob("pg-*.png")):
            try:
                rr = subprocess.run(
                    ["tesseract", str(png), "-", "--psm", "4", "-l", "eng"],
                    capture_output=True, text=True, timeout=180,
                    env={"OMP_THREAD_LIMIT": "1", "PATH": "/usr/bin:/bin:/usr/local/bin"},
                )
                texts.append(rr.stdout)
            except subprocess.TimeoutExpired:
                continue
        txt = "\n\f\n".join(texts)
        out_path.write_text(txt, encoding="utf-8")
        return {"file": fname, "status": "ok", "pages": n, "chars": len(txt)}


def main() -> None:
    max_pages = int(sys.argv[1]) if len(sys.argv) > 1 else 40
    stats = []
    done = 0
    with ThreadPoolExecutor(max_workers=8) as ex:
        futs = {ex.submit(ocr_pdf, f, max_pages): f for f in TARGETS}
        for fut in as_completed(futs):
            f = futs[fut]
            try:
                res = fut.result()
            except Exception as e:  # noqa: BLE001
                res = {"file": f, "status": f"error:{str(e)[:80]}"}
            stats.append(res)
            done += 1
            if done % 25 == 0:
                ok = sum(1 for s in stats if s["status"] in ("ok", "cached"))
                print(f"{done}/{len(TARGETS)} | ok={ok} | deferred={sum(1 for s in stats if s['status']=='deferred')}", flush=True)
    (SRC / "ocr_stats.json").write_text(json.dumps(stats, indent=1))
    from collections import Counter
    print(Counter(s["status"] for s in stats))


if __name__ == "__main__":
    main()
