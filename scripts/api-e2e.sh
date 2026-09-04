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

step "GET /me/review -> spaced-repetition queue populated by the grade"
RV=$(curl -fsS "$BASE/me/review" -H "Authorization: Bearer $TOKEN")
QTRACKED=$(printf '%s' "$RV" | jsonget "d['stats']['tracked']")
[ "$QTRACKED" -ge 1 ]
QQUEUED=$(printf '%s' "$RV" | jsonget "len(d['due']) + len(d['upcoming'])")
[ "$QQUEUED" -ge 1 ]
# fresh topic: SM-2 always schedules at least tomorrow, so it sits in upcoming
printf '%s' "$RV" | jsonget "d['upcoming'][0]['topic']" >/dev/null
printf '%s' "$RV" | jsonget "d['upcoming'][0]['dueOn']" | grep -qE "^20[0-9]{2}-[0-9]{2}-[0-9]{2}$"

step "GET /me/review without token -> 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me/review")
[ "$CODE" = "401" ]

step "GET /internal/review/tick -> disabled without ADMIN_TOKEN (404)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/internal/review/tick")
[ "$CODE" = "404" ]

# --- ROADMAP #4: syllabus map (curriculum tree + mastery overlay) ---
SYLBODY=$(printf '%s' "$BUN" | jsonget "d['body'].lower().replace(' ','-')")
step "GET /syllabus/$SYLBODY -> tree with mastery overlay"
SYL=$(curl -fsS "$BASE/syllabus/$SYLBODY" -H "Authorization: Bearer $TOKEN")
printf '%s' "$SYL" | jsonget "d['body']" >/dev/null
NTOPICS=$(printf '%s' "$SYL" | jsonget "d['stats']['topics']")
[ "$NTOPICS" -ge 1 ]
LEARNING=$(printf '%s' "$SYL" | jsonget "len([t for s in d['subjects'] for sec in s['sections'] for t in sec['topics'] if t['status']=='learning'])")
[ "$LEARNING" -ge 1 ]
WEAK=$(printf '%s' "$SYL" | jsonget "len(d['weakest'])")
[ "$WEAK" -ge 1 ]
printf '%s' "$SYL" | jsonget "d['weakest'][0]['topic']" >/dev/null

step "GET /syllabus/jamb by slug from any body -> 200 (tree exists)"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/jamb" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "200" ]

step "GET /syllabus/unknown-body -> 404"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/nope-nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "GET /syllabus without token -> 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/$SYLBODY")
[ "$CODE" = "401" ]

# --- ROADMAP #5: adaptive ordering (weak-topic-first question order) ---
step "POST /attempts adaptive:true -> order covers the pack"
ATT2=$(curl -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\",\"adaptive\":true}")
printf '%s' "$ATT2" | jsonget "d['adaptive']" | grep -q "True"
ORDERN=$(printf '%s' "$ATT2" | jsonget "len(d['order'])")
BUNDLEQ=$(printf '%s' "$BUN" | jsonget "len(d['questions'])")
[ "$ORDERN" -eq "$BUNDLEQ" ]
AID2=$(printf '%s' "$ATT2" | jsonget "d['attemptId']")

step "adaptive attempt submits + grades like any paper"
curl -fsS -X POST "$BASE/attempts/$AID2/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":[{\"questionId\":\"$Q1\",\"selected\":\"A\"}],\"durationMs\":31000}" \
  | jsonget "d['status']" | grep -q "grading"
STATUS2="grading"
for _ in $(seq 1 40); do
  STATUS2=$(curl -fsS "$BASE/attempts/$AID2" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUS2="error"
  [ "$STATUS2" = "graded" ] && break
  sleep 0.5
done
[ "$STATUS2" = "graded" ]

step "POST /attempts without adaptive -> order null (natural order)"
ATT3=$(curl -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\"}")
printf '%s' "$ATT3" | jsonget "d['adaptive']" | grep -q "False"
printf '%s' "$ATT3" | jsonget "d['order']" | grep -q "None"

# --- ROADMAP #6: fatigue telemetry ---
NOW=$(python3 -c "import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat())")
step "POST /me/sessions -> fatigue signal computed"
SESS=$(curl -fsS -X POST "$BASE/me/sessions" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\",\"startedAt\":\"$NOW\",\"endedAt\":\"$NOW\",\"durationMs\":120000,\"latenciesMs\":[8000,8000,8000,8000,8000,20000,20000,20000,20000,20000]}")
printf '%s' "$SESS" | jsonget "d['fatigue']['level']" | grep -q "mild"
printf '%s' "$SESS" | jsonget "d['fatigue']['suggestBreak']" | grep -q "True"

step "POST /me/sessions bad startedAt -> 400"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/me/sessions" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"startedAt":"not-a-time"}')
[ "$CODE" = "400" ]

step "GET /me/fatigue -> advisory state"
curl -fsS "$BASE/me/fatigue" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['level']" | grep -qE "none|mild|high"

step "GET /me/fatigue without token -> 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/me/fatigue")
[ "$CODE" = "401" ]

# --- ROADMAP #7: voice flashcards ---
step "GET /flashcards -> starter decks present"
FC=$(curl -fsS "$BASE/flashcards" -H "Authorization: Bearer $TOKEN")
DCOUNT=$(printf '%s' "$FC" | jsonget "len(d['decks'])")
[ "$DCOUNT" -ge 1 ]
DECK=$(printf '%s' "$FC" | jsonget "d['decks'][0]['code']")

step "GET /flashcards/$DECK -> cards with fronts and backs"
DK=$(curl -fsS "$BASE/flashcards/$DECK" -H "Authorization: Bearer $TOKEN")
CN=$(printf '%s' "$DK" | jsonget "len(d['cards'])")
[ "$CN" -ge 1 ]
printf '%s' "$DK" | jsonget "d['cards'][0]['front']" >/dev/null
printf '%s' "$DK" | jsonget "d['cards'][0]['back']" >/dev/null

step "GET /flashcards/nope -> 404"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/flashcards/nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "POST /me/cards/progress -> Leitner box climbs"
CARD=$(printf '%s' "$DK" | jsonget "d['cards'][0]['id']")
curl -fsS -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"deckCode\":\"$DECK\",\"grade\":\"good\"}]}" \
  | jsonget "d['progress'][0]['box']" | grep -q "2"

step "POST /me/cards/progress again -> box resets to 1"
curl -fsS -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"grade\":\"again\"}]}" \
  | jsonget "d['progress'][0]['box']" | grep -q "1"

step "POST /me/cards/progress invalid grade -> 400"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"grade\":\"maybe\"}]}")
[ "$CODE" = "400" ]

step "GET /me/cards/progress -> rows persisted"
curl -fsS "$BASE/me/cards/progress" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['progress'][0]['lastGrade']" | grep -q "again"

step "GET /flashcards without token -> 401"
CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/flashcards")
[ "$CODE" = "401" ]

printf 'ALL E2E STEPS GREEN — %s\n' "$BASE"
