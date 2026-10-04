#!/usr/bin/env python3
"""Extract text from downloaded abstechconnect PDFs.

Writes .txt next to each pdf; records extraction stats to extract_stats.json.
Only processes files whose library level matches the CLI arg (default undergrad).
"""
import json
import subprocess
import sys
from pathlib import Path

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
DETAILS = SRC / "details.jsonl"
UNDERGRAD = {"100", "200", "300", "400", "500"}


def main() -> None:
    levels = UNDERGRAD
    if len(sys.argv) > 1:
        levels = set(sys.argv[1].split(","))
    rows = [json.loads(l) for l in DETAILS.open()]
    id2rec = {r["id"]: r for r in rows}

    stats = []
    n_ok = n_bad = 0
    for pdf in sorted(PDF_DIR.glob("*.pdf")):
        lib_id = pdf.name.split("-")[0]
        # library ids are uuid-like; the filename is <uuid>-<seq>.pdf, but the
        # uuid itself contains '-', so reconstruct: strip trailing -N.pdf
        stem = pdf.stem
        lib_id = stem[: stem.rfind("-")]
        rec = id2rec.get(lib_id)
        if rec is None or rec["level"] not in levels:
            continue
        txt_path = pdf.with_suffix(".txt")
        if txt_path.exists():
            n_ok += 1
            continue
        try:
            r = subprocess.run(
                ["pdftotext", "-layout", str(pdf), "-"],
                capture_output=True, text=True, timeout=120,
            )
            txt = r.stdout
            if r.returncode != 0 or len(txt.strip()) < 40:
                n_bad += 1
                stats.append({"id": lib_id, "file": pdf.name, "chars": len(txt.strip()),
                              "status": "empty_or_failed", "err": r.stderr[:120]})
                txt_path.write_text(txt, encoding="utf-8")
                continue
            txt_path.write_text(txt, encoding="utf-8")
            n_ok += 1
            stats.append({"id": lib_id, "file": pdf.name, "chars": len(txt),
                          "status": "ok", "level": rec["level"],
                          "name": rec["name"], "institution": rec["institution"]})
        except subprocess.TimeoutExpired:
            n_bad += 1
            stats.append({"id": lib_id, "file": pdf.name, "status": "timeout"})

    (SRC / "extract_stats.json").write_text(json.dumps(stats, indent=1))
    print(f"ok={n_ok} bad={n_bad} total={n_ok+n_bad}")


if __name__ == "__main__":
    main()
