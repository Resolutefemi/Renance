#!/usr/bin/env python3
"""Live E2E for Renance study-api Gate G1 (ERA-2 walking skeleton).

Run: python3 scripts/e2e_study_g1.py   (API must be listening on BASE)

Covers: health, minimal-credential auth, profile modal contract, silent
sync job lifecycle, manifest fingerprints, bundle doctrine (no answer
material), goroutine grading (exact score from the sealed key), resubmit
guard, ownership guard, retake, tampered JWT.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("E2E_BASE", "http://127.0.0.1:3990")
REPO = Path(__file__).resolve().parents[1]
KEY_FILE = REPO / "data" / "answer-keys" / "mock" / "jamb-english-mock.json"

PASS_COUNT = 0
UNIQUE = str(int(time.time()))[-6:] + "e2e"
USER = f"g1{UNIQUE}"
USER2 = f"g1b{UNIQUE}"

FORBIDDEN = ["answer", "correct_letter", "correctletter", "explanation", "is_correct"]


def req(method, path, body=None, token=None, expect_status=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method)
    r.add_header("Content-Type", "application/json")
    if token:
        r.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(r, timeout=15) as res:
            status, payload = res.status, res.read().decode()
    except urllib.error.HTTPError as e:
        status, payload = e.code, e.read().decode()
    except Exception as exc:  # noqa: BLE001
        raise SystemExit(f"NETWORK FAILURE {method} {url}: {exc}")
    parsed = None
    if payload:
        try:
            parsed = json.loads(payload)
        except Exception:  # noqa: BLE001
            parsed = None
    if expect_status is not None and status != expect_status:
        raise SystemExit(f"FAIL {method} {path}: status {status} != {expect_status}\n{payload[:400]}")
    return status, parsed


def check(name, cond, detail=""):
    global PASS_COUNT
    if not cond:
        raise SystemExit(f"FAIL: {name} {detail}")
    PASS_COUNT += 1
    print(f"  ok {PASS_COUNT:02d}  {name}")


print(f"== Renance G1 E2E → {BASE} ==")

# 1 health
s, body = req("GET", "/healthz")
check("healthz ok", s == 200 and body.get("status") == "ok")

# 2-5 register (minimal credential flow)
s, body = req("POST", "/auth/register", {"username": USER, "password": "G1Pass!2026"})
check("register 201 + token", s == 201 and body.get("token"), str(body)[:200])
token = body["token"]
check("register returns profileCompleted=false", body["user"]["profileCompleted"] is False)

s, body = req("POST", "/auth/register", {"username": USER, "password": "G1Pass!2026"})
check("duplicate username 409", s == 409 and body["error"]["code"] == "username_taken")

s, body = req("POST", "/auth/register", {"username": "AB", "password": "G1Pass!2026"})
check("bad username 400", s == 400 and body["error"]["code"] == "invalid_username")

s, body = req("POST", "/auth/register", {"username": f"short{UNIQUE}", "password": "short"})
check("short password 400", s == 400 and body["error"]["code"] == "invalid_password")

# 6-7 login
s, body = req("POST", "/auth/login", {"username": USER, "password": "G1Pass!2026"})
check("login 200", s == 200 and body.get("token"))
s, body = req("POST", "/auth/login", {"username": USER, "password": "wrong-password"})
check("wrong password 401 generic", s == 401 and body["error"]["code"] == "invalid_credentials")

# 8-9 /me
s, body = req("GET", "/me")
check("/me unauthenticated 401", s == 401)
s, body = req("GET", "/me", token=token)
check("/me profile null before onboarding", s == 200 and body["profile"] is None)

# 10-12 profile modal contract
s, body = req("PUT", "/me/profile", {"fullName": "Test Student", "institution": "FUTA", "gradeLevel": "SS3", "exams": []}, token=token)
check("empty exams 400", s == 400 and body["error"]["code"] == "invalid_exams")

s, body = req("PUT", "/me/profile", {"fullName": "Test Student", "institution": "FUTA", "gradeLevel": "SS3", "exams": ["JAMB", "ICAN"]}, token=token)
check("unknown exam 400", s == 400 and body["error"]["code"] == "invalid_exams")

s, body = req("PUT", "/me/profile", {"fullName": "Test Student", "institution": "Federal University of Technology, Akure", "gradeLevel": "100 Level", "exams": ["JAMB", "University Modules"]}, token=token)
check("profile saved completed=true", s == 200 and body["profile"]["completed"] is True)
check("sync kicked", body.get("sync") == "kicked")

# 13 sync job lifecycle (background goroutine)
job_done = False
for _ in range(30):
    s, body = req("GET", "/sync/status", token=token)
    job = body.get("job")
    if job and job["status"] == "done" and job["progress"] == 100:
        job_done = True
        break
    time.sleep(0.4)
check("sync job reached done/100", job_done)

# 14 manifest
s, body = req("GET", "/manifest", token=token)
exams = {e["code"]: e for e in body["exams"]}
check("manifest has 5 packs", len(exams) == 5, str(len(exams)))
check("manifest sha256 fingerprints present", all(re.fullmatch(r"[0-9a-f]{64}", e["bundleSha256"]) for e in exams.values()))
check("manifest question counts", exams["jamb-english-mock"]["questionCount"] == 20 and exams["cos101-university-mock"]["questionCount"] == 15)

# 15-16 bundles + doctrine
s, body = req("GET", "/bundles/jamb-english-mock", token=token)
raw = json.dumps(body)
check("bundle 20 questions", body["questionCount"] == 20 and len(body["questions"]) == 20)
check("bundle carries NO answer material", not any(f'"{k}"' in raw for k in FORBIDDEN), "doctrine breach")

s, body = req("GET", "/bundles/definitely-not-real", token=token)
check("unknown pack 404", s == 404 and body["error"]["code"] == "unknown_pack")

# 17-21 attempts + grading engine (exact score from sealed key)
s, body = req("POST", "/attempts", {"code": "jamb-english-mock"}, token=token)
check("attempt created 201", s == 201 and body.get("attemptId") and body["status"] == "in_progress")
attempt_id = body["attemptId"]
check("attempt meta (20 Q / 15 min)", body["questionCount"] == 20 and body["durationMinutes"] == 15)

key = json.loads(KEY_FILE.read_text())["answers"]
s, bundle = req("GET", "/bundles/jamb-english-mock", token=token)
qids = [q["id"] for q in bundle["questions"]]
RIGHT, WRONG = 12, 8
answers = []
for i, qid in enumerate(qids):
    truth = key[qid]["letter"]
    lie = next(L for L in "ABCD" if L != truth)
    answers.append({"questionId": qid, "selected": truth if i < RIGHT else lie})

ghost_picks = answers[:-1] + [{"questionId": "ghost-q", "selected": "A"}]  # same length, last is alien
s, body = req("POST", f"/attempts/{attempt_id}/submit", {"answers": ghost_picks}, token=token)
check("unknown question rejected 400", s == 400 and body["error"]["code"] == "unknown_question")

s, body = req("POST", f"/attempts/{attempt_id}/submit", {"answers": answers, "durationMs": 95000}, token=token)
check("submit accepted 202 grading", s == 202 and body["status"] == "grading")

graded = None
for _ in range(40):
    s, body = req("GET", f"/attempts/{attempt_id}", token=token)
    if body["status"] == "graded":
        graded = body
        break
    time.sleep(0.3)
check("attempt graded by worker pool", graded is not None and graded.get("result") is not None)
check("score EXACTLY 12/20", graded["result"]["score"] == 12 and graded["result"]["total"] == 20, str(graded.get("result")))
check("breakdown rows present", len(graded["result"]["breakdown"]) >= 1 and all(r["total"] >= r["correct"] for r in graded["result"]["breakdown"]))

s, body = req("POST", f"/attempts/{attempt_id}/submit", {"answers": answers}, token=token)
check("resubmit rejected 409", s == 409 and body["error"]["code"] == "already_submitted")

# 22 ownership guard
s, body = req("POST", "/auth/register", {"username": USER2, "password": "G1Pass!2026"})
token2 = body["token"]
s, body = req("GET", f"/attempts/{attempt_id}", token=token2)
check("foreign attempt invisible (404)", s == 404)

# 23 retake
s, body = req("POST", "/attempts", {"code": "jamb-english-mock"}, token=token)
check("retake creates fresh attempt", s == 201 and body["attemptId"] != attempt_id)

# 24 tampered JWT
s, body = req("GET", "/me", token=token[:-4] + "AAAA")
check("tampered JWT 401", s == 401)

print(f"\nALL {PASS_COUNT} ASSERTIONS PASSED — Gate G1 exit criteria green")
sys.exit(0)
