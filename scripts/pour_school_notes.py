#!/usr/bin/env python3
"""pour_school_notes - pour data/school-notes JSON corpora into a real
school's syllabus through the /school/bulk-notes endpoint.

The endpoint is management-only and upserts topics by title, so re-pouring
a growing corpus never clobbers teacher edits (overwrite=false).

Env:
  RENANCE_API_BASE      default https://renance-api.onrender.com
  RENANCE_SCHOOL_EMAIL  management account email (required)
  RENANCE_SCHOOL_PASSWORD  (required)
  RENANCE_CLASS         optional class-name filter, e.g. "JSS 1"
  RENANCE_SUBJECT       optional subject-name filter, e.g. "Basic Science"

Usage:
  python3 scripts/pour_school_notes.py                     # pour everything
  python3 scripts/pour_school_notes.py data/school-notes/starter/jss1-first-term.json
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


def call(path: str, method: str = "GET", body: dict | None = None, token: str | None = None):
    req = Request(BASE + path, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    data = json.dumps(body).encode() if body is not None else None
    try:
        with urlopen(req, data=data, timeout=60) as r:
            return json.loads(r.read().decode())
    except HTTPError as e:
        detail = e.read().decode()[:300]
        raise SystemExit(f"{method} {path} -> {e.code}: {detail}")


def main():
    files = [Path(a) for a in sys.argv[1:]] or sorted((REPO / "data" / "school-notes").rglob("*.json"))
    files = [f for f in files if f.name != "README.md" and "cache" not in f.parts]
    if not files:
        raise SystemExit("no corpus files found under data/school-notes")

    email = os.environ.get("RENANCE_SCHOOL_EMAIL")
    password = os.environ.get("RENANCE_SCHOOL_PASSWORD")
    if not email or not password:
        raise SystemExit("set RENANCE_SCHOOL_EMAIL and RENANCE_SCHOOL_PASSWORD")

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
    print(f"pouring into: {school['name']} ({school_id[:8]}…)")

    classes = call(f"/school/classes?schoolId={school_id}", token=token)["classes"]
    subjects = call(f"/school/subjects?schoolId={school_id}", token=token)["subjects"]
    class_by_name = {c["name"]: c["id"] for c in classes}
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
        class_id = class_by_name.get(cls_name)
        subject_id = subject_by_name.get(subj_name)
        if not class_id or not subject_id:
            print(f"skip {f.name}: {cls_name!r} or {subj_name!r} not in this school")
            continue
        res = call(
            f"/school/bulk-notes?schoolId={school_id}",
            "POST",
            token=token,
            body={
                "classId": class_id,
                "subjectId": subject_id,
                "term": corpus["term"],
                "session": corpus.get("session", ""),
                "overwrite": corpus.get("overwrite", False),
                "topics": corpus["topics"],
            },
        )
        total += res.get("written", 0)
        print(f"  {f.name}: wrote {res.get('written')}/{res.get('received')} topics")
        time.sleep(0.3)
    print(f"done: {total} topics written")


if __name__ == "__main__":
    main()
