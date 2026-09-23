#!/usr/bin/env python3
"""pour_school_exams - pour data/school-exams corpora into a school's
question bank through POST /school/bulk-exam-questions.

Questions dedupe on their text server-side, so re-pouring a growing
corpus never duplicates rows. Harvested sources that publish no answer
keys carry answerIndex -1 and surface in the portal as "Key pending".

Env:
  RENANCE_API_BASE      default https://renance-api.onrender.com
  RENANCE_SCHOOL_EMAIL  management account email (required)
  RENANCE_SCHOOL_PASSWORD  (required)
  RENANCE_CLASS         optional class-name filter, e.g. "JSS 1"
  RENANCE_SUBJECT       optional subject-name filter, e.g. "Civic Education"
  RENANCE_MAX_PER_CALL  optional cap, default 500 (the endpoint's own cap)

Usage:
  python3 scripts/pour_school_exams.py
  python3 scripts/pour_school_exams.py data/school-exams/classbasic/jss-1-civic-education-term1.json
"""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

REPO = Path(__file__).resolve().parents[1]
BASE = os.environ.get("RENANCE_API_BASE", "https://renance-api.onrender.com").rstrip("/")


def call(path: str, method: str = "GET", body: dict | None = None, token: str | None = None,
         retries: int = 3):
    req = Request(BASE + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    data = json.dumps(body).encode() if body is not None else None
    last = None
    for attempt in range(retries):
        try:
            with urlopen(req, data=data, timeout=120) as r:
                return json.loads(r.read().decode())
        except HTTPError as e:
            detail = e.read().decode()[:300]
            if e.code in (502, 503, 504) and attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
                last = SystemExit(f"{method} {path} -> {e.code}: {detail}")
                continue
            raise SystemExit(f"{method} {path} -> {e.code}: {detail}")
        except Exception as e:  # noqa: BLE001 - network resets happen
            if attempt < retries - 1:
                time.sleep(3 * (attempt + 1))
                last = SystemExit(f"{method} {path} -> {e}")
                continue
            raise SystemExit(f"{method} {path} -> {e}")
    raise last or SystemExit(f"{method} {path} failed")


def main():
    files = [Path(a) for a in sys.argv[1:]] or sorted((REPO / "data" / "school-exams").rglob("*.json"))
    files = [f for f in files if f.name != "README.md"]
    if not files:
        raise SystemExit("no exam corpus files found under data/school-exams")

    email = os.environ.get("RENANCE_SCHOOL_EMAIL")
    password = os.environ.get("RENANCE_SCHOOL_PASSWORD")
    if not email or not password:
        raise SystemExit("set RENANCE_SCHOOL_EMAIL and RENANCE_SCHOOL_PASSWORD")

    cap = int(os.environ.get("RENANCE_MAX_PER_CALL", "500"))

    auth = call("/auth/login", "POST", {"email": email, "password": password})
    token = auth.get("token") or auth.get("accessToken")
    if not token:
        raise SystemExit("login did not return a token")

    me = call("/school/me", token=token)
    schools = me.get("schools") or []
    if not schools:
        raise SystemExit("this account has no school membership")
    school = schools[0]["school"]
    school_id = school["id"]
    print(f"pouring exams into: {school['name']} ({school_id[:8]}...)")

    subjects = call(f"/school/subjects?schoolId={school_id}", token=token)["subjects"]
    subject_by_name = {s["name"]: s["id"] for s in subjects}

    want_class = os.environ.get("RENANCE_CLASS")
    want_subject = os.environ.get("RENANCE_SUBJECT")

    total = 0
    for f in files:
        corpus = json.loads(f.read_text(encoding="utf-8"))
        cls_name, subj_name = corpus["class"], corpus["subject"]
        if want_class and cls_name != want_class:
            continue
        if want_subject and subj_name != want_subject:
            continue
        subject_id = subject_by_name.get(subj_name)
        if not subject_id:
            print(f"skip {f.name}: {subj_name!r} not in this school")
            continue
        questions = corpus["questions"]
        for start in range(0, len(questions), cap):
            chunk = questions[start:start + cap]
            res = call(
                f"/school/bulk-exam-questions?schoolId={school_id}",
                "POST",
                token=token,
                body={
                    "subjectId": subject_id,
                    "band": corpus.get("band") or ("primary" if cls_name.startswith("Primary") else "junior"),
                    "term": corpus["term"],
                    "session": "",
                    "source": (corpus.get("provenance") or {}).get("source", "import"),
                    "questions": chunk,
                },
            )
            total += res.get("written", 0)
            print(f"  {f.name}: {res.get('written')}/{res.get('received')} questions")
            time.sleep(0.3)
    print(f"done: {total} questions written")


if __name__ == "__main__":
    main()
