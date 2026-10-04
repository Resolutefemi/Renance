#!/usr/bin/env python3
"""Build the "Other Schools" desk: merged general-course question banks
(founder directive, 2026-10-04).

"Only schools with available past questions should be on the [selection]
list, but users whose schools are not there will select Others. For
others gather all general course questions from the other existing
schools - for example FUTA BIO101, Unilag BIO 101 - gathered together
and put under the other schools, then call it BIO 101. Do same for
other courses."

What this script does, in order:
  1. reads every per-school catalog in data/university/courses/*.json
     (the catalogs are the source of truth: each course row carries the
     exact bank code, display code, title, icon, semester)
  2. resolves each bank to its question file via data/questions/index.json
  3. groups the courses by normalized course key (bio101, gst111, ...;
     wordy course slugs stay their own key) ACROSS schools
  4. merges every school's questions for that course into ONE generic
     bank, round-robin across schools for variety, dropping duplicates
     (same stem + same options), capped at 3000 questions per course
  5. writes the merged banks to data/questions/All_tertiary_Q/others/
     with codes uni-others-<course>-bank and GENERIC titles
     ("BIO 101 | General Course Question Bank")
  6. registers every new bank in data/questions/index.json and
     data/manifest.json (real sha256 + size, no refresh pass needed)
  7. writes the catalog data/university/courses/others.json and appends
     the "Other Schools" row to data/university/schools.json (live)

Idempotent: re-running rebuilds the same banks (question order is
stable - schools sorted, questions in file order) and refreshes the
fingerprints. It never touches the per-school banks.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
COURSES_DIR = REPO / "data" / "university" / "courses"
SCHOOLS_JSON = REPO / "data" / "university" / "schools.json"
QUESTIONS_DIR = REPO / "data" / "questions"
INDEX_JSON = QUESTIONS_DIR / "index.json"
MANIFEST_JSON = REPO / "data" / "manifest.json"
OTHERS_DIR = QUESTIONS_DIR / "All_tertiary_Q" / "others"

# A merged course bank never needs more than this many questions; the
# round-robin keeps every contributing school visible near the top.
CAP_PER_COURSE = 3000
OTHERS_SLUG = "others"
OTHERS_NAME = "Other Schools"
OTHERS_SHORT = "OTHERS"
COURSE_KEY_RE = re.compile(r"^[a-z]{2,}\d+$")

VERSION = 1


def norm_stem(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "")).strip().lower()


def question_fingerprint(q: dict) -> str:
    """Same stem + same option texts = the same question (schools share
    GST-style questions heavily; students should not meet a triplet)."""
    opts = sorted(str(v).strip().lower() for v in (q.get("options") or {}).values())
    h = hashlib.sha256()
    h.update(norm_stem(q.get("stem", "")).encode("utf-8"))
    for o in opts:
        h.update(b"\x1f")
        h.update(o.encode("utf-8"))
    return h.hexdigest()


def course_key(slug: str) -> str:
    """bio101 -> bio101 (merged across schools); a wordy slug
    (financial-sector-and-eco) stays whole so it never collides with a
    coded course."""
    s = str(slug or "").strip().lower()
    if COURSE_KEY_RE.fullmatch(s):
        return s
    return s


def display_code(key: str, rows: list[dict]) -> str:
    """The generic name the founder asked for: 'BIO 101', not 'FUTA
    BIO101'. Prefer the majority display code across schools, normalized
    to LETTERS-space-DIGITS."""
    codes = [str(r.get("code") or "").strip() for r in rows]
    codes = [c for c in codes if c]
    code = Counter(codes).most_common(1)[0][0] if codes else key.upper()
    m = re.fullmatch(r"([A-Za-z]{2,})\s*(\d+[A-Za-z]?)", code)
    if m:
        return f"{m.group(1).upper()} {m.group(2).upper()}"
    return code.upper()


def wordy_title(slug: str) -> str:
    return " ".join(w.capitalize() for w in slug.split("-") if w)


def majority(rows: list[dict], field: str, default):
    vals = [r.get(field) for r in rows]
    vals = [v for v in vals if v not in (None, "", 0)]
    if not vals:
        return default
    try:
        return Counter(vals).most_common(1)[0][0]
    except TypeError:  # unhashable edge
        return vals[0]


def bank_questions(bank_code: str, index: dict) -> list[dict] | None:
    rel = index.get(bank_code)
    if not rel:
        return None
    path = QUESTIONS_DIR / rel
    if not path.exists():
        return None
    try:
        bundle = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    qs = bundle.get("questions") or []
    return qs if isinstance(qs, list) and qs else None


def pretty_code(slug: str) -> str:
    """gst101 -> GST 101; financial-sector-and-eco stays wordy-caps."""
    if COURSE_KEY_RE.fullmatch(slug):
        m = re.fullmatch(r"([a-z]+)(\d+[a-z]?)", slug)
        return f"{m.group(1).upper()} {m.group(2).upper()}"
    return wordy_title(slug)


def course_bank_rows(index: dict) -> dict[str, tuple[str, str]]:
    """bank code -> (school slug, course slug) for every UNIVERSITY course
    bank in the index (Post-UTME pq shelves excluded). School slugs may
    carry dashes, so the split mirrors build.py's heuristic: the tail is
    a course code (bio101) -> last dash; wordy tails -> first dash."""
    out: dict[str, tuple[str, str]] = {}
    for code in index:
        if not code.startswith("uni-") or not code.endswith("-bank") or "-pq-" in code:
            continue
        stem = code[4:-5]
        school, _, course = stem.rpartition("-")
        if not (school and course and COURSE_KEY_RE.fullmatch(course)):
            first, _, rest = stem.partition("-")
            school, course = first, rest
        if school and course:
            out[code] = (school, course)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true",
                    help="print the merge plan without writing anything")
    args = ap.parse_args()

    index = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST_JSON.read_text(encoding="utf-8"))
    existing_codes = {e["code"] for e in manifest["exams"]}

    # 0. catalog repair: banks registered in the index but whose course
    #    rows never landed in the school's catalog (aau GST101/GST102/
    #    ENT201/ENT211, uniosun MTH101 - the banks are real, the desks
    #    just never listed them). Their own school's desk gets the rows.
    all_course_banks = course_bank_rows(index)
    repaired: list[tuple[str, str, int]] = []
    catalogs = [p for p in sorted(COURSES_DIR.glob("*.json"))
                if p.stem != OTHERS_SLUG]
    grouped: dict[str, list[dict]] = defaultdict(list)
    school_count = 0
    for cat_path in catalogs:
        try:
            cat = json.loads(cat_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            print(f"skip unreadable catalog {cat_path.name}")
            continue
        slug = str(cat.get("school") or cat_path.stem).strip().lower()
        if slug == OTHERS_SLUG:
            continue
        school_count += 1
        referenced = {str(c.get("bank") or "") for c in cat.get("courses") or []}
        cat_repaired = False
        for bank_code, (b_school, b_course) in sorted(all_course_banks.items()):
            if b_school != slug or bank_code in referenced:
                continue
            qs = bank_questions(bank_code, index)
            if not qs:
                continue
            cat.setdefault("courses", []).append({
                "slug": b_course,
                "code": pretty_code(b_course),
                "title": None,
                "semester": 1,
                "icon": "menu_book",
                "bank": bank_code,
                "questionCount": len(qs),
                "pdf": None,
            })
            repaired.append((slug, bank_code, len(qs)))
            cat_repaired = True
        if cat_repaired and not args.dry_run:
            cat_path.write_text(
                json.dumps(cat, ensure_ascii=False, indent=1) + "\n",
                encoding="utf-8")
        for course in cat.get("courses") or []:
            bank = str(course.get("bank") or "").strip()
            if not bank or "-pq-" in bank:
                continue  # Post-UTME shelves are a separate desk
            key = course_key(str(course.get("slug") or ""))
            if not key:
                continue
            grouped[key].append({
                "school": slug,
                "bank": bank,
                "code": course.get("code"),
                "title": course.get("title"),
                "icon": course.get("icon"),
                "semester": course.get("semester"),
                "questionCount": course.get("questionCount"),
            })

    # 0b. orphan rescue: banks whose school has NO catalog at all
    #     (fupre - the school was retired in the PDF cleanup, its 84
    #     GST111 questions are real). They fold into the Others merge so
    #     the content keeps serving instead of rotting unreachable.
    catalog_schools = {str(json.loads(p.read_text(encoding="utf-8")).get("school") or p.stem).strip().lower()
                       for p in catalogs}
    rescued: list[tuple[str, str, int]] = []
    for bank_code, (b_school, b_course) in sorted(all_course_banks.items()):
        if b_school in catalog_schools or b_school == OTHERS_SLUG:
            continue
        qs = bank_questions(bank_code, index)
        if not qs:
            continue
        grouped[course_key(b_course)].append({
            "school": b_school,
            "bank": bank_code,
            "code": pretty_code(b_course),
            "title": None,
            "icon": "menu_book",
            "semester": 1,
            "questionCount": len(qs),
        })
        rescued.append((b_school, bank_code, len(qs)))

    # 2. merge each course group into one generic bank
    OTHERS_DIR.mkdir(parents=True, exist_ok=True)
    catalog_courses: list[dict] = []
    new_index_rows: dict[str, str] = {}
    stats: list[tuple[str, int, int, int]] = []  # key, schools, raw, kept

    for key in sorted(grouped):
        rows = grouped[key]
        per_school: dict[str, list[dict]] = defaultdict(list)
        for r in rows:
            qs = bank_questions(r["bank"], index)
            if qs:
                per_school[r["school"]].extend(qs)
        if not per_school:
            continue
        schools = sorted(per_school)
        # round-robin one question per school until cap or exhaustion
        queues = [list(per_school[s]) for s in schools]
        heads = [0] * len(queues)
        seen: set[str] = set()
        merged: list[dict] = []
        raw_total = sum(len(q) for q in queues)
        progressed = True
        while len(merged) < CAP_PER_COURSE and progressed:
            progressed = False
            for i, queue in enumerate(queues):
                if heads[i] >= len(queue):
                    continue
                progressed = True
                q = queue[heads[i]]
                heads[i] += 1
                fp = question_fingerprint(q)
                if fp in seen:
                    continue
                seen.add(fp)
                merged.append(q)
                if len(merged) >= CAP_PER_COURSE:
                    break

        # renumber + keep every grading field (answer/explanation ride
        # inline - the API harvests them at load, per the one-file doctrine)
        bank_code = f"uni-{OTHERS_SLUG}-{key}-bank"
        renumbered = []
        for n, q in enumerate(merged, start=1):
            q = dict(q)
            q["id"] = f"{bank_code}-{n:04d}"
            renumbered.append(q)
        code_disp = display_code(key, rows)
        title = (str(majority(rows, "title", "") or "").strip()
                 or (wordy_title(key) if not COURSE_KEY_RE.fullmatch(key) else ""))
        title_disp = f"{code_disp} | General Course Question Bank"
        total_marks = sum(int(q.get("marks") or 1) for q in renumbered)
        bundle = {
            "code": bank_code,
            "title": title_disp,
            "version": VERSION,
            "questionCount": len(renumbered),
            "totalMarks": total_marks,
            "questions": renumbered,
            "category": "university",
            "body": "University Modules",
        }
        rel = f"All_tertiary_Q/{OTHERS_SLUG}/{key.upper() if COURSE_KEY_RE.fullmatch(key) else key}.json"
        if not args.dry_run:
            out = QUESTIONS_DIR / rel
            out.parent.mkdir(parents=True, exist_ok=True)
            raw = json.dumps(bundle, ensure_ascii=False,
                             separators=(",", ":")).encode("utf-8") + b"\n"
            out.write_bytes(raw)
            new_index_rows[bank_code] = rel
            sha = hashlib.sha256(raw).hexdigest()
            if bank_code in existing_codes:
                for e in manifest["exams"]:
                    if e["code"] == bank_code:
                        e.update(questionCount=len(renumbered),
                                 totalMarks=total_marks,
                                 bundleSha256=sha,
                                 sizeBytes=len(raw))
                        break
            else:
                manifest["exams"].append({
                    "code": bank_code,
                    "title": title_disp,
                    "questionCount": len(renumbered),
                    "totalMarks": total_marks,
                    "category": "university",
                    "body": "University Modules",
                    "bundleSha256": sha,
                    "sizeBytes": len(raw),
                })
        catalog_courses.append({
            "slug": key,
            "code": code_disp,
            "title": title or None,
            "semester": majority(rows, "semester", 1) or 1,
            "icon": majority(rows, "icon", "menu_book") or "menu_book",
            "bank": bank_code,
            "questionCount": len(renumbered),
            "pdf": None,
        })
        stats.append((key, len(schools), raw_total, len(renumbered)))

    # 3. the Others catalog
    others_catalog = {
        "school": OTHERS_SLUG,
        "name": OTHERS_NAME,
        "short": OTHERS_SHORT,
        "courses": sorted(catalog_courses, key=lambda c: c["code"]),
    }
    # 4. schools.json: the live Others row
    schools = json.loads(SCHOOLS_JSON.read_text(encoding="utf-8"))
    school_list = schools["schools"]
    school_list = [s for s in school_list if s.get("slug") != OTHERS_SLUG]
    school_list.append({
        "slug": OTHERS_SLUG,
        "short": OTHERS_SHORT,
        "name": OTHERS_NAME,
        "type": "university",
        "state": "Nationwide",
        "live": True,
    })

    if args.dry_run:
        for slug, bank_code, n in repaired:
            print(f"  repair: {slug} catalog gains {bank_code} ({n} Q)")
        for slug, bank_code, n in rescued:
            print(f"  rescue: {slug} {bank_code} ({n} Q) folds into Others")
        for key, n_schools, raw, kept in stats:
            print(f"  {key}: {n_schools} schools, {raw} raw -> {kept} kept")
        print(f"courses: {len(stats)}  (from {school_count} school catalogs)")
        return 0

    (COURSES_DIR / f"{OTHERS_SLUG}.json").write_text(
        json.dumps(others_catalog, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    SCHOOLS_JSON.write_text(
        json.dumps({"schools": school_list}, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")

    # 5. index + manifest. Styles match the current committed files so
    # the diff stays append-only: index.json rides its indent-1 style
    # with the new codes appended, manifest.json rides the minified
    # refresh_manifest.py convention.
    index.update(new_index_rows)
    INDEX_JSON.write_text(
        json.dumps(index, ensure_ascii=False, indent=1) + "\n",
        encoding="utf-8")
    MANIFEST_JSON.write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")) + "\n",
        encoding="utf-8")

    print(f"merged {len(stats)} general courses from {school_count} school catalogs")
    for slug, bank_code, n in repaired:
        print(f"  repaired {slug} catalog row: {bank_code} ({n} Q)")
    for slug, bank_code, n in rescued:
        print(f"  rescued orphan into Others: {slug} {bank_code} ({n} Q)")
    for key, n_schools, raw, kept in stats:
        dup = raw - kept
        dup_s = f" ({dup} dups/capped)" if dup else ""
        print(f"  {key}: {n_schools} schools, {kept} questions{dup_s}")
    print(f"banks written to {OTHERS_DIR.relative_to(REPO)}/")
    print(f"catalog: data/university/courses/{OTHERS_SLUG}.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
