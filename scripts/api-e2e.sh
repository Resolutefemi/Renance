#!/usr/bin/env bash
# Renance study-api end-to-end probe — the EXACT flow a new student takes:
# health → register → duplicate-register → login → bad-password →
# me → profile → manifest → bundle → attempt → submit → grade.
#
# Usage: scripts/api-e2e.sh [BASE_URL]   (default http://127.0.0.1:3990)
# Exit 0 only if every step is green.
set -euo pipefail

BASE="${1:-http://127.0.0.1:3990}"

jsonget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1"; }
step() { printf '▸ %s\n' "$1"; }

step "healthz (db must be ok)"
curl -fsS "$BASE/healthz" | grep -q '"db":"ok"'

USERNAME="e2e$RANDOM$RANDOM"
PASSWORD="e2e-password-1"

step "register $USERNAME → 201 + token"
REG=$(curl -fsS -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
TOKEN=$(printf '%s' "$REG" | jsonget "d['token']")
[ -n "$TOKEN" ]

step "duplicate register → 409"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
[ "$CODE" = "409" ]

step "login → 200"
LOGIN=$(curl -fsS -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
printf '%s' "$LOGIN" | jsonget "d['user']['username']" | grep -q "$(printf '%s' "$USERNAME" | sed 's/[][*.$]/\\&/g')"

step "login wrong password → 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"wrongwrong\"}")
[ "$CODE" = "401" ]

step "google auth without config → 503 (or 401 with bad credential when enabled)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/google" \
  -H 'Content-Type: application/json' -d '{"credential":"not-a-token"}')
[ "$CODE" = "503" ] || [ "$CODE" = "401" ]

step "GET /me without token → 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me")
[ "$CODE" = "401" ]

step "GET /me → profileCompleted false"
curl -fsS "$BASE/me" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['user']['profileCompleted']" | grep -q "False"

step "PUT /me/profile → completed true"
curl -fsS -X PUT "$BASE/me/profile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fullName":"E2E Student","institution":"University of Lagos","gradeLevel":"SS3","exams":["JAMB","University Modules"]}' \
  | jsonget "d['profile']['completed']" | grep -q "True"

step "GET /manifest → packs present"
MAN=$(curl -fsS "$BASE/manifest" -H "Authorization: Bearer $TOKEN")
PACK=$(printf '%s' "$MAN" | jsonget "d['exams'][0]['code']")

step "GET /bundles/$PACK → questions present"
BUN=$(curl -fsS "$BASE/bundles/$PACK" -H "Authorization: Bearer $TOKEN")
Q1=$(printf '%s' "$BUN" | jsonget "d['questions'][0]['id']")
Q2=$(printf '%s' "$BUN" | jsonget "d['questions'][1]['id']")

step "POST /attempts → attemptId"
ATT=$(curl -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\"}")
AID=$(printf '%s' "$ATT" | jsonget "d['attemptId']")

step "submit answers → grading"
curl -fsS -X POST "$BASE/attempts/$AID/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":[{\"questionId\":\"$Q1\",\"selected\":\"A\"},{\"questionId\":\"$Q2\",\"selected\":\"B\"}],\"durationMs\":42000}" \
  | jsonget "d['status']" | grep -q "grading"

step "poll until graded → result present"
STATUS="grading"
for _ in $(seq 1 40); do
  STATUS=$(curl -fsS "$BASE/attempts/$AID" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUS="error"
  [ "$STATUS" = "graded" ] && break
  sleep 0.5
done
[ "$STATUS" = "graded" ]
curl -fsS "$BASE/attempts/$AID" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['result']['score']" >/dev/null

step "PUT /me/profile with targetYear -> stored"
curl -fsS -X PUT "$BASE/me/profile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fullName":"E2E Student","institution":"University of Lagos","gradeLevel":"SS3","exams":["JAMB"],"targetYear":2027}' \
  | jsonget "d['profile']['targetYear']" | grep -q "2027"

step "GET /me/attempts -> 1 graded paper"
N=$(curl -fsS "$BASE/me/attempts" -H "Authorization: Bearer $TOKEN" \
  | jsonget "len(d['attempts'])")
[ "$N" -ge 1 ]
curl -fsS "$BASE/me/attempts" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['attempts'][0]['status']" | grep -q "graded"

step "GET /me/attempts bad token -> 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me/attempts" -H "Authorization: Bearer nope")
[ "$CODE" = "401" ]

step "GET /attempts/$AID/review -> per-question detail unlocked"
REV=$(curl -fsS "$BASE/attempts/$AID/review" -H "Authorization: Bearer $TOKEN")
RQN=$(printf '%s' "$REV" | jsonget "len(d['questions'])")
[ "$RQN" -ge 2 ]
printf '%s' "$REV" | jsonget "d['questions'][0]['correct']" | grep -qE "^[A-H]$"
printf '%s' "$REV" | jsonget "d['questions'][0]['stem']" >/dev/null

printf 'ALL E2E STEPS GREEN — %s\n' "$BASE"
