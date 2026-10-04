#!/usr/bin/env python3
"""Bank parsed abstechconnect MCQs into the Renance question format.

Reads data/src/abstechconnect/details.jsonl + parses each target library's
PDFs, then writes/merges banks:

  - undergrad course PQs  -> data/questions/All_tertiary_Q/<school>/<COURSE>.json
                             code: uni-<school>-<course>-bank
  - post-UTME papers      -> data/questions/POST_UTME/<school>/<subject>.json
                             code: uni-<school>-pq-<subject>-bank

Dedup: by normalized stem against existing questions in the target bank and
across source files. Sources are logged in _sources.json.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from abc_parse_bank import load_text, parse_mcqs, dedup  # noqa: E402

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
REPO = SRC.parents[2]
ALL_TERT = REPO / "data" / "questions" / "All_tertiary_Q"
POST_UTME = REPO / "data" / "questions" / "POST_UTME"

SCHOOL_SLUGS = {
    "ambrose alli university, ekpoma": "aau",
    "osun state university osogbo": "uniosun",
    "federal university of petroleum resources, effurun-(fupre)": "fupre",
    "federal university of petroleum resources, effurun (fupre)": "fupre",
    "federal university of petroleum resources effurun": "fupre",
    "university of port harcourt": "uniport",
    "university of calabar": "unical",
    "ekiti state university": "eksu",
    "lagos state university, ojo": "lasu",
    "university of benin": "uniben",
    "niger delta university yenagoa": "ndu",
    "delta state university, abraka": "delsu",
    "federal university of technology, minna": "futminna",
    "university of ilorin": "unilorin",
    "university of lagos": "unilag",
    "obafemi awolowo university, ile-ife": "oau",
    "college of education, warri (affiliated to delsu)": "coewarri",
    "college of education, warri": "coewarri",
    "ekiti state university (eksu)": "eksu",
}

COURSE_RE = re.compile(r"\b([A-Z]{2,4})[\s\-/]?(\d{3})\b")


def school_slug(rec: dict) -> str:
    inst = (rec.get("institution") or "").strip().lower()
    if inst in SCHOOL_SLUGS:
        return SCHOOL_SLUGS[inst]
    # author fallback (e.g. author="NDU")
    a = (rec.get("author") or "").strip().lower()
    for k, v in SCHOOL_SLUGS.items():
        pass
    return None


def course_code(name: str):
    m = COURSE_RE.search((name or "").upper())
    if m:
        dept, num = m.group(1), m.group(2)
        # normalize common CS spellings
        dept = {"CSC": "csc", "GST": "gst", "GNS": "gns", "ENT": "ent",
                "MTH": "mth", "CHM": "chm", "PHY": "phy", "BIO": "bio",
                "EEE": "eee", "CHE": "che", "MEE": "mee", "PET": "pet",
                "PEE": "pee", "STA": "sta", "CPT": "cpt", "MAT": "mth",
                "ACC": "acc", "GES": "ges", "GSE": "ges"}.get(dept, dept.lower())
        return f"{dept}{num}"
    return None


def bank_path(code: str, category: str) -> Path:
    if category == "university":
        school, course = code.split("-")[1], code.split("-")[2]
        p = ALL_TERT / school / f"{course.upper()}.json"
    else:  # post-utme
        # code: uni-<school>-pq-<subject>-bank
        school = code.split("-")[1]
        subject = code.split("-")[3]
        p = POST_UTME / school / f"{subject}.json"
    p.parent.mkdir(parents=True, exist_ok=True)
    return p


def load_existing(p: Path) -> dict | None:
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text())
    except Exception:  # noqa: BLE001
        return None


def make_bank(code: str, title: str, questions: list[dict], category: str) -> dict:
    prefix = code
    qs = []
    for i, q in enumerate(questions, 1):
        qs.append({
            "id": f"{prefix}-{i:04d}",
            "type": "mcq",
            "stem": q["stem"],
            "options": {k: q["options"].get(k, "") for k in "ABCD"},
            "marks": 1,
            "answer": q["answer"],
            "explanation": "",
        })
    return {
        "code": code,
        "title": title,
        "version": 1,
        "questionCount": len(qs),
        "totalMarks": len(qs),
        "questions": qs,
        "category": category,
        "body": "University Modules" if category == "university" else "Post-UTME Past Questions",
    }


def stem_key(s: str) -> str:
    return re.sub(r"\W+", "", s.lower())[:120]


def merge_bank(path: Path, code: str, title: str, new_qs: list[dict], category: str) -> dict:
    existing = load_existing(path)
    if existing and existing.get("code") != code:
        # same file reused by another code - shouldn't happen; bail
        raise RuntimeError(f"code mismatch at {path}")
    if existing:
        seen = {stem_key(q["stem"]) for q in existing["questions"]}
        added = [q for q in new_qs if stem_key(q["stem"]) not in seen]
        merged = existing["questions"] + [
            {
                "id": f"{code}-{len(existing['questions']) + j + 1:04d}",
                "type": "mcq",
                "stem": q["stem"],
                "options": {k: q["options"].get(k, "") for k in "ABCD"},
                "marks": 1,
                "answer": q["answer"],
                "explanation": "",
            }
            for j, q in enumerate(added)
        ]
        existing["questions"] = merged
        existing["questionCount"] = len(merged)
        existing["totalMarks"] = len(merged)
        return {"bank": existing, "added": len(added), "path": path, "mode": "merge"}
    bank = make_bank(code, title, new_qs, category)
    return {"bank": bank, "added": len(new_qs), "path": path, "mode": "create"}


TARGETS = [
    # library_id, category, school_override, course_or_subject, title_suffix
    ("0b3a35ad-41fa-4573-886f-3b1df11acd61", "university", "aau", "gst102", "GST 102"),
    ("17374bce-2615-431d-a1a7-8757eb643147", "university", "aau", "ent211", "ENT 211"),
    ("af6a81f5-8a93-49c7-9128-291208fe9359", "university", "aau", "gst101", "GST 101"),
    ("afa6d00a-51e0-4669-ab87-0f8ca615cb9f", "university", "aau", "ent201", "ENT 201"),
    ("ed272ab8-6955-48f1-a425-5f043567a295", "university", "aau", "gst102", "GST 102"),
    ("ba696dd0-eb48-4786-bd67-f3b781981559", "university", "aau", "gst102", "GST 102"),
    ("382e4f90-1287-43a4-b6b5-97ced7b29a5c", "university", "uniosun", "mth101", "MTH 101"),
    ("add5531d-3f49-4636-8689-43ebdb7d018d", "university", "fupre", "gst111", "GST 111"),
    ("ba7a16e1-cd09-481a-ac58-34a3eea4579a", "university", "fupre", "gst111", "GST 111"),
    ("c9307020-7cd2-462b-b03d-9623d992d7d8", "university", "fupre", "gst111", "GST 111"),
    ("d2746bea-d672-4fd9-a2d9-83ba6e12e261", "university", "fupre", "gst111", "GST 111"),
]

SCHOOL_TITLES = {
    "aau": "AAU", "uniosun": "UNIOSUN", "fupre": "FUPRE",
    "uniport": "UNIPORT", "unical": "UNICAL", "eksu": "EKSU",
}


def main() -> None:
    dry = "--dry" in sys.argv
    report = []
    for lib_id, category, school, course, title_sfx in TARGETS:
        stems = sorted(p.stem for p in PDF_DIR.glob(lib_id + "-*.pdf"))
        if not stems:
            report.append({"lib": lib_id, "error": "no pdfs"})
            continue
        qs = []
        for stem in stems:
            text, mode = load_text(stem)
            got = dedup(parse_mcqs(text))
            qs.extend(got)
        qs = dedup(qs)
        if not qs:
            report.append({"lib": lib_id, "error": "no questions parsed"})
            continue

        course_up = course.upper()
        school_t = SCHOOL_TITLES.get(school, school.upper())
        if category == "university":
            code = f"uni-{school}-{course}-bank"
            title = f"{school_t} {title_sfx} | Course Question Bank"
        else:
            code = f"uni-{school}-pq-{course}-bank"
            title = f"{school_t} Post-UTME {title_sfx} | Practice Bank"
        path = bank_path(code, category)
        res = merge_bank(path, code, title, qs, category)
        report.append({
            "lib": lib_id, "code": code, "mode": res["mode"],
            "added": res["added"], "parsed": len(qs), "path": str(path.relative_to(REPO)),
        })
        if not dry:
            path.write_text(json.dumps(res["bank"], indent=1, ensure_ascii=False), encoding="utf-8")

    print(json.dumps(report, indent=1))
    total_added = sum(r.get("added", 0) for r in report)
    print(f"\nbanked questions: {total_added}")
    (SRC / "bank_report.json").write_text(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
