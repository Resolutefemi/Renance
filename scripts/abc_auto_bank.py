#!/usr/bin/env python3
"""Auto-bank every abstechconnect PQ paper that parses with answer keys.

Scans all libraries (any school in the map), picks the best text per pdf,
parses MCQs, banks into All_tertiary_Q/<school>/<COURSE>.json with stem
dedup. Skips libraries already banked this way (marker file).
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from abc_parse_bank import load_text, parse_mcqs, dedup  # noqa: E402
from renance_pdf_gen import SCHOOL_MAP, extract_course  # noqa: E402

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
REPO = SRC.parents[2]
ALL_TERT = REPO / "data" / "questions" / "All_tertiary_Q"
MARKER = SRC / "banked_libs.json"

SCHOOL_SHORT = {
    "fupre": "FUPRE", "uniosun": "UNIOSUN", "aau": "AAU", "uniport": "UNIPORT",
    "coewarri": "COE WARRI", "pti": "PTI", "futminna": "FUT MINNA",
    "fubk": "FUBK", "fedpolyilaro": "FEDPOLY ILARO", "deltapoly": "DELTAPOLY",
    "nsuk": "NSUK", "eksu": "EKSU", "lasu": "LASU", "evangel": "EVANGEL",
    "crawford": "CRAWFORD", "futa": "FUTA", "unical": "UNICAL",
}


def main() -> None:
    dry = "--dry" in sys.argv
    details = [json.loads(l) for l in (SRC / "details.jsonl").open()]
    banked = set()
    if MARKER.exists():
        banked = set(json.loads(MARKER.read_text()))

    report = []
    total_new = 0
    new_banked = set(banked)
    n_seen = 0
    todo = [r for r in details if r["id"] not in banked]
    for rec in todo:
        n_seen += 1
        if n_seen % 25 == 0:
            print(f"  ...{n_seen}/{len(todo)} libs | banked rows: {len(report)}", flush=True)
        lib_id = rec["id"]
        if lib_id in banked:
            continue
        inst = (rec.get("institution") or "").strip().lower()
        school = SCHOOL_MAP.get(inst)
        if not school:
            continue
        cc = extract_course(rec.get("name") or "")
        if not cc:
            continue
        code, display = cc
        stems = sorted(p.stem for p in PDF_DIR.glob(lib_id + "-*.pdf"))
        if not stems:
            continue
        qs = []
        for stem in stems:
            try:
                # fast path: OCR/layout text first; reconstruction is slow
                ocr = PDF_DIR / (stem + ".ocr.txt")
                lay = PDF_DIR / (stem + ".txt")
                cands = []
                if ocr.exists():
                    cands.append(ocr.read_text(errors="ignore"))
                if lay.exists():
                    cands.append(lay.read_text(errors="ignore"))
                if cands:
                    text = max(cands, key=len)
                else:
                    text, _mode = load_text(stem)
                qs.extend(dedup(parse_mcqs(text)))
            except Exception:  # noqa: BLE001
                continue
        qs = dedup(qs)
        # require a decent yield before banking
        if len(qs) < 10:
            new_banked.add(lib_id)  # parsed-out or unparsable: don't retry
            continue

        slug = school[0]
        bank_code = f"uni-{slug}-{code.lower()}-bank"
        path = ALL_TERT / slug / f"{code.upper()}.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        existing = None
        if path.exists():
            try:
                existing = json.loads(path.read_text())
            except Exception:  # noqa: BLE001
                existing = None
        seen = set()
        if existing:
            for q in existing["questions"]:
                seen.add(re.sub(r"\W+", "", q["stem"].lower())[:120])
        fresh = [q for q in qs if re.sub(r"\W+", "", q["stem"].lower())[:120] not in seen]
        if not fresh:
            new_banked.add(lib_id)
            continue

        if existing and existing.get("code") == bank_code:
            base = len(existing["questions"])
            for i, q in enumerate(fresh, 1):
                existing["questions"].append({
                    "id": f"{bank_code}-{base + i:04d}",
                    "type": "mcq", "stem": q["stem"],
                    "options": {k: q["options"].get(k, "") for k in "ABCD"},
                    "marks": 1, "answer": q["answer"], "explanation": "",
                })
            existing["questionCount"] = len(existing["questions"])
            existing["totalMarks"] = len(existing["questions"])
            bank = existing
        else:
            bank = {
                "code": bank_code,
                "title": f"{SCHOOL_SHORT.get(slug, slug.upper())} {display} | Course Question Bank",
                "version": 1, "questionCount": len(fresh), "totalMarks": len(fresh),
                "questions": [
                    {"id": f"{bank_code}-{i:04d}", "type": "mcq", "stem": q["stem"],
                     "options": {k: q["options"].get(k, "") for k in "ABCD"},
                     "marks": 1, "answer": q["answer"], "explanation": ""}
                    for i, q in enumerate(fresh, 1)
                ],
                "category": "university", "body": "University Modules",
            }
        total_new += len(fresh)
        report.append((slug, code, len(qs), len(fresh), bank.get("code")))
        new_banked.add(lib_id)
        if not dry:
            path.write_text(json.dumps(bank, indent=1, ensure_ascii=False), encoding="utf-8")

    if not dry:
        MARKER.write_text(json.dumps(sorted(new_banked)))
    print(f"{'school':<12} {'course':<8} {'parsed':>6} {'new':>5}")
    for slug, code, n, fresh, bc in report:
        print(f"{slug:<12} {code:<8} {n:>6} {fresh:>5}")
    print(f"\nTOTAL new questions: {total_new} {'(DRY)' if dry else ''}")
    print(f"libraries marked banked: {len(new_banked)}/{len(details)}")


if __name__ == "__main__":
    main()
