#!/usr/bin/env bash
# Renance study-api end-to-end probe, the EXACT flow a new student takes:
# health → register → duplicate-register → login → bad-password →
# me → profile → manifest → bundle → attempt → submit → grade.
#
# Usage: scripts/api-e2e.sh [BASE_URL]   (default http://127.0.0.1:3990)
# Exit 0 only if every step is green.
set -euo pipefail

BASE="${1:-http://127.0.0.1:3990}"

jsonget() { python3 -c "import json,sys;d=json.load(sys.stdin);print(eval(sys.argv[1]))" "$1"; }
step() { printf '▸ %s\n' "$1"; }

step "readyz (the REAL Postgres probe - healthz is DB-free by doctrine)"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/readyz" | grep -q '"db":"ok"'
step "healthz answers DB-free (never wakes Neon)"
printf '%s' "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/healthz")" | grep -q '"db":"not-probed'

USERNAME="e2e$RANDOM$RANDOM"
PASSWORD="e2e-password-1"

step "register $USERNAME → 201 + token"
REG=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
TOKEN=$(printf '%s' "$REG" | jsonget "d['token']")
[ -n "$TOKEN" ]

step "duplicate register → 409"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
[ "$CODE" = "409" ]

step "login → 200"
LOGIN=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}")
printf '%s' "$LOGIN" | jsonget "d['user']['username']" | grep -q "$(printf '%s' "$USERNAME" | sed 's/[][*.$]/\\&/g')"

step "login wrong password → 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$USERNAME\",\"password\":\"wrongwrong\"}")
[ "$CODE" = "401" ]

step "google auth without config → 503 (or 401 with bad credential when enabled)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/google" \
  -H 'Content-Type: application/json' -d '{"credential":"not-a-token"}')
[ "$CODE" = "503" ] || [ "$CODE" = "401" ]

step "GET /me without token → 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/me")
[ "$CODE" = "401" ]

step "GET /me → profileCompleted false"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['user']['profileCompleted']" | grep -q "False"

step "PUT /me/profile → completed true"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/me/profile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fullName":"E2E Student","institution":"University of Lagos","gradeLevel":"SS3","exams":["JAMB","University Modules"]}' \
  | jsonget "d['profile']['completed']" | grep -q "True"

step "GET /manifest → packs present"
MAN=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/manifest" -H "Authorization: Bearer $TOKEN")
# The probe paper must carry syllabus topics: the graded attempt seats the
# SM-2 review rows the /syllabus overlay (LEARNING/WEAK assertions below)
# reads, and topic-less questions seat under "General", outside every
# syllabus tree. jamb-english-bank leads because 1,500+ of its questions
# carry real JAMB-tree topics (Synonyms / Antonyms / Grammar, tagged from
# their own instruction stems and validated in-tree at boot); fall back
# to any -mock pack, then the first body-carrying bank.
PACK=$(printf '%s' "$MAN" | jsonget "([e['code'] for e in d['exams'] if e['code'] == 'jamb-english-bank'] + [e['code'] for e in d['exams'] if e['code'].endswith('-mock')] + [e['code'] for e in d['exams'] if e.get('body')])[0]")

step "GET /bundles/$PACK → questions present"
BUN=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/bundles/$PACK" -H "Authorization: Bearer $TOKEN")
Q1=$(printf '%s' "$BUN" | jsonget "[q['id'] for q in d['questions'] if q.get('topic')][0]")
Q2=$(printf '%s' "$BUN" | jsonget "[q['id'] for q in d['questions'] if q.get('topic')][1]")

step "GET /bundles/$PACK → per-question answers ship (founder directive 2026-09, web statics parity)"
printf '%s' "$BUN" | python3 -c "
import json,sys
b=json.load(sys.stdin)
mcq=[q for q in b['questions'] if q.get('options')]
assert mcq, 'bank carries no MCQs to check'
withans=[q for q in mcq if q.get('answer')]
assert withans, 'static bank must ship per-question answer material (study reader grades/explains offline)'
"

step "POST /attempts → attemptId"
ATT=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\"}")
AID=$(printf '%s' "$ATT" | jsonget "d['attemptId']")

step "submit answers → grading"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$AID/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":[{\"questionId\":\"$Q1\",\"selected\":\"A\"},{\"questionId\":\"$Q2\",\"selected\":\"B\"}],\"durationMs\":42000}" \
  | jsonget "d['status']" | grep -q "grading"

step "poll until graded → result present"
STATUS="grading"
for _ in $(seq 1 40); do
  STATUS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$AID" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUS="error"
  [ "$STATUS" = "graded" ] && break
  sleep 0.5
done
[ "$STATUS" = "graded" ]
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$AID" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['result']['score']" >/dev/null

step "PUT /me/profile with targetYear -> stored"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/me/profile" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"fullName":"E2E Student","institution":"University of Lagos","gradeLevel":"SS3","exams":["JAMB"],"targetYear":2027}' \
  | jsonget "d['profile']['targetYear']" | grep -q "2027"

step "GET /me/attempts -> 1 graded paper"
N=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me/attempts" -H "Authorization: Bearer $TOKEN" \
  | jsonget "len(d['attempts'])")
[ "$N" -ge 1 ]
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me/attempts" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['attempts'][0]['status']" | grep -q "graded"

step "GET /me/attempts bad token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/me/attempts" -H "Authorization: Bearer nope")
[ "$CODE" = "401" ]

step "GET /attempts/$AID/review -> per-question detail unlocked"
REV=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$AID/review" -H "Authorization: Bearer $TOKEN")
RQN=$(printf '%s' "$REV" | jsonget "len(d['questions'])")
[ "$RQN" -ge 2 ]
printf '%s' "$REV" | jsonget "d['questions'][0]['correct']" | grep -qE "^[A-H]$"
printf '%s' "$REV" | jsonget "d['questions'][0]['stem']" >/dev/null

step "GET /me/review -> spaced-repetition queue populated by the grade"
# The grading engine seats review topics a few round-trips after the
# result lands; on a remote DB that trails the graded flag, so poll.
RV=""
for _ in $(seq 1 20); do
  RV=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me/review" -H "Authorization: Bearer $TOKEN")
  QTRACKED=$(printf '%s' "$RV" | jsonget "d['stats']['tracked']")
  [ "$QTRACKED" -ge 1 ] && break
  sleep 1
done
[ "$QTRACKED" -ge 1 ]
QQUEUED=$(printf '%s' "$RV" | jsonget "len(d['due']) + len(d['upcoming'])")
[ "$QQUEUED" -ge 1 ]
# fresh topic: SM-2 always schedules at least tomorrow, so it sits in upcoming
printf '%s' "$RV" | jsonget "d['upcoming'][0]['topic']" >/dev/null
printf '%s' "$RV" | jsonget "d['upcoming'][0]['dueOn']" | grep -qE "^20[0-9]{2}-[0-9]{2}-[0-9]{2}$"

step "GET /me/review without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/me/review")
[ "$CODE" = "401" ]

step "GET /internal/review/tick -> disabled without ADMIN_TOKEN (404)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/internal/review/tick")
[ "$CODE" = "404" ]

# --- ROADMAP #4: syllabus map (curriculum tree + mastery overlay) ---
# The graded probe attempt (jamb-english-bank) seats JAMB review rows, so
# the tree read here must be the probe bank's own body, not whatever body
# happens to lead the manifest (retired bodies like gcse would 404).
SYLBODY=$(printf '%s' "$MAN" | jsonget "[e['body'].lower().replace(' ','-') for e in d['exams'] if e['code'] == 'jamb-english-bank' and e.get('body')][0]")
step "GET /syllabus/$SYLBODY -> tree with mastery overlay"
SYL=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/syllabus/$SYLBODY" -H "Authorization: Bearer $TOKEN")
printf '%s' "$SYL" | jsonget "d['body']" >/dev/null
NTOPICS=$(printf '%s' "$SYL" | jsonget "d['stats']['topics']")
[ "$NTOPICS" -ge 1 ]
LEARNING=$(printf '%s' "$SYL" | jsonget "len([t for s in d['subjects'] for sec in s['sections'] for t in sec['topics'] if t['status']=='learning'])")
[ "$LEARNING" -ge 1 ]
WEAK=$(printf '%s' "$SYL" | jsonget "len(d['weakest'])")
[ "$WEAK" -ge 1 ]
printf '%s' "$SYL" | jsonget "d['weakest'][0]['topic']" >/dev/null

step "GET /syllabus/jamb by slug from any body -> 200 (tree exists)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/jamb" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "200" ]

step "GET /syllabus/unknown-body -> 404"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/nope-nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "GET /syllabus without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/syllabus/$SYLBODY")
[ "$CODE" = "401" ]

# --- ROADMAP #5: adaptive ordering (weak-topic-first question order) ---
step "POST /attempts adaptive:true -> order covers the pack"
ATT2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\",\"adaptive\":true}")
printf '%s' "$ATT2" | jsonget "d['adaptive']" | grep -q "True"
ORDERN=$(printf '%s' "$ATT2" | jsonget "len(d['order'])")
BUNDLEQ=$(printf '%s' "$BUN" | jsonget "len(d['questions'])")
[ "$ORDERN" -eq "$BUNDLEQ" ]
AID2=$(printf '%s' "$ATT2" | jsonget "d['attemptId']")

step "adaptive attempt submits + grades like any paper"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$AID2/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":[{\"questionId\":\"$Q1\",\"selected\":\"A\"}],\"durationMs\":31000}" \
  | jsonget "d['status']" | grep -q "grading"
STATUS2="grading"
for _ in $(seq 1 40); do
  STATUS2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$AID2" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUS2="error"
  [ "$STATUS2" = "graded" ] && break
  sleep 0.5
done
[ "$STATUS2" = "graded" ]

step "POST /attempts without adaptive -> order null (natural order)"
ATT3=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\"}")
printf '%s' "$ATT3" | jsonget "d['adaptive']" | grep -q "False"
printf '%s' "$ATT3" | jsonget "d['order']" | grep -q "None"

# --- ROADMAP #6: fatigue telemetry ---
NOW=$(python3 -c "import datetime;print(datetime.datetime.now(datetime.timezone.utc).isoformat())")
step "POST /me/sessions -> fatigue signal computed"
SESS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/me/sessions" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\",\"startedAt\":\"$NOW\",\"endedAt\":\"$NOW\",\"durationMs\":120000,\"latenciesMs\":[8000,8000,8000,8000,8000,20000,20000,20000,20000,20000]}")
printf '%s' "$SESS" | jsonget "d['fatigue']['level']" | grep -q "mild"
printf '%s' "$SESS" | jsonget "d['fatigue']['suggestBreak']" | grep -q "True"

step "POST /me/sessions bad startedAt -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/me/sessions" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"startedAt":"not-a-time"}')
[ "$CODE" = "400" ]

step "GET /me/fatigue -> advisory state"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me/fatigue" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['level']" | grep -qE "none|mild|high"

step "GET /me/fatigue without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/me/fatigue")
[ "$CODE" = "401" ]

# --- ROADMAP #7: voice flashcards ---
step "GET /flashcards -> starter decks present"
FC=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/flashcards" -H "Authorization: Bearer $TOKEN")
DCOUNT=$(printf '%s' "$FC" | jsonget "len(d['decks'])")
[ "$DCOUNT" -ge 1 ]
DECK=$(printf '%s' "$FC" | jsonget "d['decks'][0]['code']")

step "GET /flashcards/$DECK -> cards with fronts and backs"
DK=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/flashcards/$DECK" -H "Authorization: Bearer $TOKEN")
CN=$(printf '%s' "$DK" | jsonget "len(d['cards'])")
[ "$CN" -ge 1 ]
printf '%s' "$DK" | jsonget "d['cards'][0]['front']" >/dev/null
printf '%s' "$DK" | jsonget "d['cards'][0]['back']" >/dev/null

step "GET /flashcards/nope -> 404"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/flashcards/nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "POST /me/cards/progress -> Leitner box climbs"
CARD=$(printf '%s' "$DK" | jsonget "d['cards'][0]['id']")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"deckCode\":\"$DECK\",\"grade\":\"good\"}]}" \
  | jsonget "d['progress'][0]['box']" | grep -q "2"

step "POST /me/cards/progress again -> box resets to 1"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"grade\":\"again\"}]}" \
  | jsonget "d['progress'][0]['box']" | grep -q "1"

step "POST /me/cards/progress invalid grade -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/me/cards/progress" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"grades\":[{\"cardId\":\"$CARD\",\"grade\":\"maybe\"}]}")
[ "$CODE" = "400" ]

step "GET /me/cards/progress -> rows persisted"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me/cards/progress" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['progress'][0]['lastGrade']" | grep -q "again"

step "GET /flashcards without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/flashcards")
[ "$CODE" = "401" ]

# --- ROADMAP #8: lessons (mdx-built content bundles) ---
step "GET /lessons -> mdx-built lessons present"
LS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/lessons" -H "Authorization: Bearer $TOKEN")
LCOUNT=$(printf '%s' "$LS" | jsonget "len(d['lessons'])")
[ "$LCOUNT" -ge 1 ]
LSLUG=$(printf '%s' "$LS" | jsonget "d['lessons'][0]['slug']")
printf '%s' "$LS" | jsonget "d['lessons'][0]['summary']" >/dev/null

step "GET /lessons/$LSLUG -> sections with typed blocks"
L1=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/lessons/$LSLUG" -H "Authorization: Bearer $TOKEN")
SN=$(printf '%s' "$L1" | jsonget "len(d['sections'])")
[ "$SN" -ge 1 ]
printf '%s' "$L1" | jsonget "d['sections'][0]['heading']" >/dev/null
printf '%s' "$L1" | jsonget "d['sections'][0]['blocks'][0]['type']" >/dev/null

step "GET /lessons/nope -> 404"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/lessons/nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "GET /lessons without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/lessons")
[ "$CODE" = "401" ]

step "GET /career -> curated scholarships + course paths (ROADMAP #18)"
CR=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/career" -H "Authorization: Bearer $TOKEN")
SCOUNT=$(printf '%s' "$CR" | jsonget "len(d['scholarships'])")
[ "$SCOUNT" -ge 5 ]
PCOUNT=$(printf '%s' "$CR" | jsonget "len(d['paths'])")
[ "$PCOUNT" -ge 8 ]
printf '%s' "$CR" | jsonget "d['scholarships'][0]['window']" >/dev/null
printf '%s' "$CR" | jsonget "d['paths'][0]['topics'][0]" >/dev/null

step "GET /career without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/career")
[ "$CODE" = "401" ]

# --- ROADMAP #9: Socratic tutor (hint mode without an AI key) ---
step "GET /tutor/status -> aiEnabled false (no key configured)"
TS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/tutor/status" -H "Authorization: Bearer $TOKEN")
printf '%s' "$TS" | jsonget "d['aiEnabled']" | grep -q "False"

step "POST /attempts/$AID/tutor -> hint-mode coaching"
T1=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$AID/tutor" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"questionId\":\"$Q1\",\"messages\":[{\"role\":\"user\",\"content\":\"Why is my answer wrong?\"}]}")
printf '%s' "$T1" | jsonget "d['mode']" | grep -q "hint"
printf '%s' "$T1" | jsonget "d['reply']" >/dev/null

step "tutor second turn -> ladder advances"
T2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$AID/tutor" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"questionId\":\"$Q1\",\"messages\":[{\"role\":\"user\",\"content\":\"Still stuck\"},{\"role\":\"assistant\",\"content\":\"hint1\"},{\"role\":\"user\",\"content\":\"More help?\"}]}")
printf '%s' "$T2" | jsonget "d['mode']" | grep -q "hint"

step "tutor on ungraded attempt -> 409"
ATT4=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$PACK\"}")
AID4=$(printf '%s' "$ATT4" | jsonget "d['attemptId']")
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts/$AID4/tutor" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"questionId\":\"$Q1\",\"messages\":[{\"role\":\"user\",\"content\":\"help\"}]}")
[ "$CODE" = "409" ]

step "tutor with unknown question -> 404"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts/$AID/tutor" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"questionId\":\"nope\",\"messages\":[{\"role\":\"user\",\"content\":\"help\"}]}")
[ "$CODE" = "404" ]

step "tutor with empty messages -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts/$AID/tutor" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"questionId\":\"$Q1\",\"messages\":[]}")
[ "$CODE" = "400" ]

step "tutor without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts/$AID/tutor" \
  -H 'Content-Type: application/json' -d '{"questionId":"x","messages":[{"role":"user","content":"hi"}]}')
[ "$CODE" = "401" ]

# --- security hardening ---
step "security headers on every response"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -D - -o /dev/null "$BASE/healthz" | grep -qi "X-Content-Type-Options: nosniff"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -D - -o /dev/null "$BASE/healthz" | grep -qi "X-Frame-Options: DENY"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -D - -o /dev/null "$BASE/healthz" | grep -qi "Cache-Control: no-store"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -D - -o /dev/null "$BASE/healthz" | grep -qi "Content-Security-Policy: default-src"

# --- ROADMAP #14: multiplayer arena over WebSockets ---
step "arena ws e2e (two students, full live match)"
(cd "$(dirname "$0")/../apps/study-api" && go run ./cmd/arena-e2e "$BASE")

# --- ROADMAP #14 slice: leaderboards over arena + study data ---
step "GET /leaderboard/arena -> the two arena students ranked, caller has no rank yet"
LB=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/leaderboard/arena?period=all" -H "Authorization: Bearer $TOKEN")
[ "$(printf '%s' "$LB" | jsonget "len(d['entries'])")" -ge 2 ]
printf '%s' "$LB" | jsonget "d['entries'][0]['username']" >/dev/null
# The arena e2e students pick one RANDOM shared letter per question, so the
# top entry's points are only shape-checked (they can legitimately be 0).
printf '%s' "$LB" | jsonget "d['entries'][0]['points']" | grep -qE "^[0-9]+$"
printf '%s' "$LB" | jsonget "d['me']" | grep -q "None"

step "GET /leaderboard/arena default period -> week board"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/leaderboard/arena" -H "Authorization: Bearer $TOKEN" \
  | jsonget "d['period']" | grep -q "week"

step "GET /leaderboard/arena bad period -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/leaderboard/arena?period=month" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "400" ]

step "GET /leaderboard/arena without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/leaderboard/arena")
[ "$CODE" = "401" ]

step "GET /leaderboard/streak -> caller ranked after their graded papers"
XB=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/leaderboard/streak" -H "Authorization: Bearer $TOKEN")
printf '%s' "$XB" | jsonget "d['me']['rank']" | grep -qE "^[0-9]+$"
[ "$(printf '%s' "$XB" | jsonget "d['me']['attempts']")" -ge 1 ]
[ "$(printf '%s' "$XB" | jsonget "len(d['entries'])")" -ge 1 ]

step "GET /leaderboard/streak without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/leaderboard/streak")
[ "$CODE" = "401" ]

step "GET /leaderboard/focus?focus=jamb -> board answers (mock ledger sums to /400)"
JB=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/leaderboard/focus?focus=jamb" -H "Authorization: Bearer $TOKEN")
printf '%s' "$JB" | jsonget "d['board']" | grep -q "focus"
printf '%s' "$JB" | jsonget "d['entries']" >/dev/null

step "GET /leaderboard/focus bad focus -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/leaderboard/focus?focus=utme" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "400" ]

step "GET /leaderboard/schools -> gone (schools are not ranked, founder directive 2026-09-30)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/leaderboard/schools" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

# --- Email-confirmation gate (founder directive 2026-09-30): an email
# signup that never confirmed is locked out; the login re-sends the mail
# and answers 403 email_unverified with a restricted session that opens
# ONLY the confirmation surface. ---
step "register with email -> 201 + restricted session"
EEMAIL="e2e-gate$RANDOM$RANDOM@example.com"
EREG=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EEMAIL\",\"password\":\"$PASSWORD\",\"verifyReturn\":\"web\"}")
ETOKEN=$(printf '%s' "$EREG" | jsonget "d['token']")
[ -n "$ETOKEN" ]
printf '%s' "$EREG" | jsonget "d['emailVerification']['required']" | grep -q "True"

step "restricted session: /me answers (allowlisted), /manifest answers 403 email_unverified"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/me" -H "Authorization: Bearer $ETOKEN" >/dev/null
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/manifest" -H "Authorization: Bearer $ETOKEN")
[ "$CODE" = "403" ]

step "restricted session: /auth/refresh stays 403 while unconfirmed"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/refresh" \
  -H "Authorization: Bearer $ETOKEN" -H 'Content-Type: application/json' -d '{}')
[ "$CODE" = "403" ]

step "login with unconfirmed email -> 403 email_unverified + restricted token"
ELOGIN=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -w '\n%{http_code}' -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EEMAIL\",\"password\":\"$PASSWORD\"}")
ECODE=$(printf '%s' "$ELOGIN" | tail -1)
[ "$ECODE" = "403" ]
printf '%s' "$ELOGIN" | head -1 | jsonget "d['error']['code']" | grep -q "email_unverified"
printf '%s' "$ELOGIN" | head -1 | jsonget "d['token']" >/dev/null

step "verify-email with a bogus code -> 400 invalid_token"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/verify-email" \
  -H 'Content-Type: application/json' -d '{"code":"000000"}')
[ "$CODE" = "400" ]

# --- Dead-code regression guard (founder directive 2026-10-03, code
# era 2026-10-05): re-sends (blocked login, resend button) used to
# OVERWRITE verify_token, so the confirmation code already sitting in
# the student's inbox answered "not valid any more" and the account
# could never be confirmed. The column now holds a list of the recent
# expiry-stamped codes: any unexpired one verifies. A change-email
# still resets the list (a code mailed to the OLD address must never
# verify the NEW one). ---
step "change-email rescue -> 200, _devCode carries the fresh 6-digit code"
ENEWEMAIL="e2e-changed$RANDOM$RANDOM@example.com"
ECHANGE=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/me/change-email" \
  -H "Authorization: Bearer $ETOKEN" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENEWEMAIL\",\"return\":\"web\"}")
CCODE=$(printf '%s' "$ECHANGE" | jsonget "d['_devCode']")
[ -n "$CCODE" ]
printf '%s' "$ECHANGE" | jsonget "d['email']" | grep -q "$ENEWEMAIL"

step "blocked login with the new address re-sends a second mail (must NOT kill the first link)"
ELOGIN2=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -w '\n%{http_code}' -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENEWEMAIL\",\"password\":\"$PASSWORD\"}")
[ "$(printf '%s' "$ELOGIN2" | tail -1)" = "403" ]

step "the change-email code STILL verifies after the re-send -> verified:true"
EVERIFY=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/verify-email" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CCODE\"}")
printf '%s' "$EVERIFY" | jsonget "d['verified']" | grep -q "True"

step "the code works once - a replay answers 400 invalid_token"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/verify-email" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$CCODE\"}")
[ "$CODE" = "400" ]

step "login with the new address after confirming -> 200 seated session"
ELOGIN3=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$ENEWEMAIL\",\"password\":\"$PASSWORD\"}")
printf '%s' "$ELOGIN3" | jsonget "d['token']" >/dev/null

# --- First-code regression (founder bug 2026-10-05: "the first code
# doesn't work, the second one does"): the signup's OWN 6-digit code
# verified nothing - with DEVICE_LOCK off, bindDevice never ran
# EnsureEntitlement, so the entitlements row did not exist at stamp time,
# the bare UPDATE hit zero rows and the code was silently dropped; only
# a resent code (whose handler Ensures the row first) worked. The stamp
# is now an upsert, and the signup response carries _devCode (parity
# with resend + change-email) so this flow is pinned. ---
step "register a second email -> 201 + the signup's own _devCode"
EEMAIL2="e2e-first$RANDOM$RANDOM@example.com"
EREG2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EEMAIL2\",\"password\":\"$PASSWORD\"}")
ETOKEN2=$(printf '%s' "$EREG2" | jsonget "d['token']")
[ -n "$ETOKEN2" ]
FIRSTCODE=$(printf '%s' "$EREG2" | jsonget "d['_devCode']")
[ -n "$FIRSTCODE" ]

step "the FIRST signup code verifies with no resend -> verified:true"
FVERIFY=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/verify-email" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$FIRSTCODE\"}")
printf '%s' "$FVERIFY" | jsonget "d['verified']" | grep -q "True"

step "first code works once - replay answers 400 invalid_token"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/auth/verify-email" \
  -H 'Content-Type: application/json' -d "{\"code\":\"$FIRSTCODE\"}")
[ "$CODE" = "400" ]

step "login after the first-code verify -> 200 seated session"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EEMAIL2\",\"password\":\"$PASSWORD\"}" | jsonget "d['token']" >/dev/null

# --- ROADMAP #20: deterministic daily challenge ---
step "GET /daily/JAMB -> today's deterministic challenge"
D1=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB" -H "Authorization: Bearer $TOKEN")
printf '%s' "$D1" | jsonget "d['day']" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"
DCODE=$(printf '%s' "$D1" | jsonget "d['code']")
printf '%s' "$DCODE" | grep -q "^jamb-"
printf '%s' "$D1" | jsonget "d['body']" | grep -q "JAMB"
DN=$(printf '%s' "$D1" | jsonget "len(d['questions'])")
[ "$DN" -ge 1 ] && [ "$DN" -le 10 ]
printf '%s' "$D1" | jsonget "d['myResult']" | grep -q "None"

step "GET /daily/JAMB -> byte-identical on refetch (pure function of day+body)"
D2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB" -H "Authorization: Bearer $TOKEN")
[ "$D1" = "$D2" ]

step "GET /daily/University%20Modules -> 200; the pick comes from a school that ships banks"
UMD=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/University%20Modules" -H "Authorization: Bearer $TOKEN")
printf '%s' "$UMD" | jsonget "d['body']" | grep -q "University Modules"
printf '%s' "$UMD" | jsonget "d['code']" | grep -qE "^uni-[a-z0-9-]+"
printf '%s' "$UMD" | jsonget "len(d['questions'])" | grep -qx "10"

step "GET /daily/jamb (lowercase) -> canonical JAMB challenge serves whole"
UMLC=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/jamb" -H "Authorization: Bearer $TOKEN")
printf '%s' "$UMLC" | jsonget "d['body']" | grep -q "JAMB"

step "GET /daily/WAEC -> 200 now that WAEC banks carry that body"
WAEC=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/WAEC" -H "Authorization: Bearer $TOKEN")
printf '%s' "$WAEC" | jsonget "d['body']" | grep -q "WAEC"
printf '%s' "$WAEC" | jsonget "len(d['questions'])" | grep -qx "10"

step "GET /daily/NECO -> 200 now that the 37-subject archive ships NECO banks"
NECO=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/NECO" -H "Authorization: Bearer $TOKEN")
printf '%s' "$NECO" | jsonget "d['body']" | grep -q "NECO"
printf '%s' "$NECO" | jsonget "len(d['questions'])" | grep -qx "10"

step "GET /daily/JAMB without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/daily/JAMB")
[ "$CODE" = "401" ]

step "POST /attempts daily:true on a non-challenge JAMB pack -> 409"
OTHER=$(printf '%s' "$MAN" | python3 -c "import json,sys;m=json.load(sys.stdin);print([e['code'] for e in m['exams'] if e.get('body')=='JAMB' and e['code']!='$DCODE'][0])")
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$OTHER\",\"daily\":true}")
[ "$CODE" = "409" ]

step "POST /attempts daily:true -> attempt pinned to today's challenge"
DATT=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$DCODE\",\"daily\":true}")
DAID=$(printf '%s' "$DATT" | jsonget "d['attemptId']")
printf '%s' "$DATT" | jsonget "d['daily']" | grep -q "True"
[ "$(printf '%s' "$DATT" | jsonget "len(d['order'])")" -eq "$DN" ]

step "daily submit with an out-of-selection question -> 400 not_in_daily"
DBUN=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/bundles/$DCODE" -H "Authorization: Bearer $TOKEN")
DIDS=$(printf '%s' "$D1" | jsonget "','.join(q['id'] for q in d['questions'])")
OUTQ=$(printf '%s' "$DBUN" | DIDS="$DIDS" python3 -c "
import json,os,sys
d=json.load(sys.stdin)
daily=set(os.environ['DIDS'].split(','))
rest=[q['id'] for q in d['questions'] if q['id'] not in daily]
print(rest[0] if rest else '')")
[ -n "$OUTQ" ]
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/attempts/$DAID/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":[{\"questionId\":\"$OUTQ\",\"selected\":\"A\"}]}")
[ "$CODE" = "400" ]

step "submit the daily challenge -> graded"
DANSWERS=$(printf '%s' "$D1" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(json.dumps([{'questionId':q['id'],'selected':sorted(q.get('options',{}))[0]} for q in d['questions'] if q.get('options')]))")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$DAID/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":$DANSWERS,\"durationMs\":45000}" \
  | jsonget "d['status']" | grep -q "grading"
STATUSD="grading"
for _ in $(seq 1 40); do
  STATUSD=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$DAID" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUSD="error"
  [ "$STATUSD" = "graded" ] && break
  sleep 0.5
done
[ "$STATUSD" = "graded" ]

step "GET /daily/JAMB -> myResult seated with challenge-sized total"
# The seat is written best-effort by the grading worker AFTER the attempt
# flips to graded (gamification and review ride the same async tail), so
# give it a short window instead of racing the worker on a remote DB.
MYATTEMPT=""
for _ in $(seq 1 20); do
  MYATTEMPT=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB" -H "Authorization: Bearer $TOKEN" \
    | jsonget "d['myResult']['attemptId'] if d['myResult'] else ''") || true
  [ -n "$MYATTEMPT" ] && break
  sleep 0.5
done
[ -n "$MYATTEMPT" ]
printf '%s' "$MYATTEMPT" | grep -q "$DAID"
DRTOTAL=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB" -H "Authorization: Bearer $TOKEN" | jsonget "d['myResult']['total']")
[ "$DRTOTAL" -eq "$DN" ]

step "GET /daily/JAMB/leaderboard -> caller ranked on today's board"
DLB=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB/leaderboard" -H "Authorization: Bearer $TOKEN")
printf '%s' "$DLB" | jsonget "d['code']" | grep -q "$DCODE"
printf '%s' "$DLB" | jsonget "d['me']['rank']" | grep -qE "^[0-9]+$"
[ "$(printf '%s' "$DLB" | jsonget "len(d['entries'])")" -ge 1 ]

step "GET /daily/JAMB/leaderboard?day=not-a-day -> 400"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/daily/JAMB/leaderboard?day=nope" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "400" ]

step "replay the daily -> seat unchanged (first graded submission wins)"
DATT2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$DCODE\",\"daily\":true}")
DAID2=$(printf '%s' "$DATT2" | jsonget "d['attemptId']")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$DAID2/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":$DANSWERS,\"durationMs\":30000}" \
  | jsonget "d['status']" | grep -q "grading"
STATUSD2="grading"
for _ in $(seq 1 40); do
  STATUSD2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$DAID2" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUSD2="error"
  [ "$STATUSD2" = "graded" ] && break
  sleep 0.5
done
[ "$STATUSD2" = "graded" ]
DR2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/daily/JAMB" -H "Authorization: Bearer $TOKEN")
printf '%s' "$DR2" | jsonget "d['myResult']['attemptId']" | grep -q "$DAID"

step "GET /daily/JAMB/leaderboard without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/daily/JAMB/leaderboard")
[ "$CODE" = "401" ]

step "auth flood -> 429 once the per-IP burst is exhausted"
# The auth bucket is AUTH_PER_MIN*2 = 40 tokens per client IP. The flood is
# fired CONCURRENTLY and pins a single X-Forwarded-For hop so all 60 hits
# land in ONE bucket, otherwise multi-homed runners (CI egress rotation,
# Render's proxy hops) spread the requests across several buckets and the
# 429 count drops below the assertion. Verified against production Render:
# 60 pinned concurrent -> 40x400 + 20x429, exactly the burst design.
CODES=$(seq 1 60 | xargs -P 12 -I{} curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}\n' \
  -X POST "$BASE/auth/register" \
  -H 'Content-Type: application/json' \
  -H 'X-Forwarded-For: 203.0.113.7' \
  -d '{"username":"x","password":"short"}')
N429=$(printf '%s\n' "$CODES" | grep -c '^429$')
[ "$N429" -ge 10 ]



# ----------------------------------------------------------------------
# Composite UTME mock papers: begin -> compose -> play -> grade -> review
# ----------------------------------------------------------------------

MOCKCODE="jamb-mock-english-biology-mathematics-physics"

step "GET /bundles/$MOCKCODE -> composite paper composed with sections"
MOCKBUNDLE=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/bundles/$MOCKCODE" -H "Authorization: Bearer $TOKEN")
printf '%s' "$MOCKBUNDLE" | jsonget "d['body']" | grep -q "JAMB"
[ "$(printf '%s' "$MOCKBUNDLE" | jsonget "d['durationMinutes']")" = "120" ]
[ "$(printf '%s' "$MOCKBUNDLE" | jsonget "len(d['sections'])")" = "4" ]
printf '%s' "$MOCKBUNDLE" | jsonget "d['sections'][0]['subject']" | grep -q "Use of English"
MQN=$(printf '%s' "$MOCKBUNDLE" | jsonget "d['questionCount']")
[ "$MQN" -gt 0 ]

step "composed bundle never carries answer-material KEYS (ADR-0003)"
printf '%s' "$MOCKBUNDLE" | python3 -c "
import json,sys
def keys(o):
    if isinstance(o,dict):
        for k,v in o.items():
            yield str(k).lower()
            yield from keys(v)
    elif isinstance(o,list):
        for v in o: yield from keys(v)
b=json.load(sys.stdin)
forbidden={'answer','answers','answer_key','answerkey','correct','correct_answer','correctletter','correct_letter','correctoption','correct_option','explanation','explanations','iscorrect','is_correct'}
bad=[k for k in keys(b) if k in forbidden]
assert not bad, f'answer-material keys leaked: {bad}'
"

step "deterministic compose: refetch serves the identical walk"
MOCKBUNDLE2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/bundles/$MOCKCODE" -H "Authorization: Bearer $TOKEN")
[ "$(printf '%s' "$MOCKBUNDLE" | jsonget "[q['id'] for q in d['questions']]")" = "$(printf '%s' "$MOCKBUNDLE2" | jsonget "[q['id'] for q in d['questions']]")" ]

step "non-canonical mock code -> 404"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/bundles/jamb-mock-english-physics-mathematics-biology" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "unknown-subject mock code -> 404 (slug segments against shipped banks only)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/bundles/jamb-mock-english-latin-physics" -H "Authorization: Bearer $TOKEN")
[ "$CODE" = "404" ]

step "POST /attempts for the mock paper -> seated with the composed pack"
MATT=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"code\":\"$MOCKCODE\"}")
MAID=$(printf '%s' "$MATT" | jsonget "d['attemptId']")
[ "$(printf '%s' "$MATT" | jsonget "d['questionCount']")" = "$MQN" ]
[ "$(printf '%s' "$MATT" | jsonget "d['durationMinutes']")" = "120" ]

step "submit one answer per subject -> grading"
MANSWERS=$(printf '%s' "$MOCKBUNDLE" | jsonget "json.dumps([{'questionId': d['sections'][i]['questionIds'][0], 'selected': 'A'} for i in range(4)])")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/attempts/$MAID/submit" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d "{\"answers\":$MANSWERS,\"durationMs\":60000}" \
  | jsonget "d['status']" | grep -q "grading"
STATUSM="grading"
for _ in $(seq 1 40); do
  STATUSM=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$MAID" -H "Authorization: Bearer $TOKEN" | jsonget "d['status']") || STATUSM="error"
  [ "$STATUSM" = "graded" ] && break
  sleep 0.5
done
[ "$STATUSM" = "graded" ]

step "graded mock result: breakdown covers the whole paper"
# Breakdown rows are per TOPIC. Since the English bank ships topicful
# questions (tagged from its own instruction stems), the composed paper
# mixes topic rows with the "General" bucket of topic-less subjects, so
# the honest invariant: at least one row, the paper total is intact, and
# the rows' totals SUM to every question in the paper.
MRES=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$MAID" -H "Authorization: Bearer $TOKEN")
[ "$(printf '%s' "$MRES" | jsonget "len(d['result']['breakdown'])")" -ge 1 ]
[ "$(printf '%s' "$MRES" | jsonget "d['result']['total']")" = "$MQN" ]
[ "$(printf '%s' "$MRES" | jsonget "sum(r['total'] for r in d['result']['breakdown'])")" = "$MQN" ]

step "review the mock attempt -> paper title is the bare quiz name"
MREV=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/attempts/$MAID/review" -H "Authorization: Bearer $TOKEN")
printf '%s' "$MREV" | jsonget "d['title']" | grep -q "^UTME Mock$"

# ======================================================================
# SCHOOL PLATFORM E2E: register -> setup -> students -> attendance ->
# bulk-notes -> results -> finalize -> PIN check. Proves the new
# migration + endpoints against the same real Postgres.
# ======================================================================
SCHOOLNAME="e2e school $RANDOM"
SCHOOK="e2e-school-$RANDOM$RANDOM"

step "school: register -> 201 + management membership + curriculum seed"
SREG=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"schoolName\":\"$SCHOOLNAME\",\"schoolType\":\"both\",\"fullName\":\"E2E Principal\",\"email\":\"$SCHOOK@example.com\",\"password\":\"$PASSWORD\"}")
STOKEN=$(printf '%s' "$SREG" | jsonget "d['token']")
[ -n "$STOKEN" ]
SCHOOLID=$(printf '%s' "$SREG" | jsonget "d['school']['id']")
SEEDED=$(printf '%s' "$SREG" | jsonget "d['seededClasses']")
[ "$SEEDED" -ge 12 ]

step "school: profile update stamps a logo data URL"
LOGO="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg=="
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/profile?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"name\":\"$SCHOOLNAME\",\"address\":\"1 E2E Road\",\"logoUrl\":\"$LOGO\"}" \
  | jsonget "d['school']['logoUrl']" | grep -q "^data:image/png"

step "school: classes + subjects seeded with departments"
CLASSES=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/classes?schoolId=$SCHOOLID" -H "Authorization: Bearer $STOKEN")
JSS1=$(printf '%s' "$CLASSES" | jsonget "[c['id'] for c in d['classes'] if c['name']=='JSS 1'][0]")
SSS1=$(printf '%s' "$CLASSES" | jsonget "[c['id'] for c in d['classes'] if c['name']=='SSS 1'][0]")
SUBS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/subjects?schoolId=$SCHOOLID" -H "Authorization: Bearer $STOKEN")
PHY=$(printf '%s' "$SUBS" | jsonget "[s['id'] for s in d['subjects'] if s['name']=='Physics'][0]")
GOV=$(printf '%s' "$SUBS" | jsonget "[s['id'] for s in d['subjects'] if s['name']=='Government'][0]")
ENG=$(printf '%s' "$SUBS" | jsonget "[s['id'] for s in d['subjects'] if s['name']=='English Language'][0]")
[ "$(printf '%s' "$SUBS" | jsonget "[s for s in d['subjects'] if s['name']=='Physics'][0]['department']")" = "science" ]
[ "$(printf '%s' "$SUBS" | jsonget "[s for s in d['subjects'] if s['name']=='Government'][0]['department']")" = "art" ]
[ "$(printf '%s' "$SUBS" | jsonget "[s for s in d['subjects'] if s['name']=='English Language'][0]['isCore']")" = "True" ]

step "school: enroll two students with full details"
STUD1=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/students?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"fullName\":\"Ada Obi\",\"admissionNo\":\"SS1-001\",\"sex\":\"F\",\"session\":\"2025/2026\"}" | jsonget "d['student']['id']")
STUD2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/students?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"fullName\":\"Bola Ade\",\"admissionNo\":\"SS1-002\",\"sex\":\"M\",\"session\":\"2025/2026\"}" | jsonget "d['student']['id']")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/student?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"id\":\"$STUD1\",\"fullName\":\"Ada Obi\",\"dob\":\"2010-05-01\",\"guardianName\":\"Mrs Obi\",\"guardianPhone\":\"08030000001\",\"address\":\"12 Ada Street\"}" \
  | jsonget "d['student']['guardianName']" | grep -q "Obi"

step "school: per-student subject offering (science track)"
OFFERING=$(printf '%s' "$SUBS" | jsonget "json.dumps([s['id'] for s in d['subjects'] if s['department']=='science' or s['isCore']][:6])")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/student-subjects?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"studentId\":\"$STUD1\",\"subjectIds\":$OFFERING}" | jsonget "d['ok']" | grep -q "True"
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/student-subjects?schoolId=$SCHOOLID&studentId=$STUD1" -H "Authorization: Bearer $STOKEN" | jsonget "len(d['subjectIds'])")" -ge 1 ]

step "school: attendance day save + summary"
TODAY=$(date +%F)
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/attendance?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"classId\":\"$SSS1\",\"day\":\"$TODAY\",\"entries\":[{\"studentId\":\"$STUD1\",\"status\":\"present\",\"note\":\"\"},{\"studentId\":\"$STUD2\",\"status\":\"late\",\"note\":\"traffic\"}]}" \
  | jsonget "d['saved']" | grep -q "^2$"
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/attendance?schoolId=$SCHOOLID&classId=$SSS1&day=$TODAY" -H "Authorization: Bearer $STOKEN" | jsonget "len(d['entries'])")" = "2" ]
# re-marking the same day is an upsert: one student flips to late, count stays 2
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/attendance?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"day\":\"$TODAY\",\"entries\":[{\"studentId\":\"$STUD1\",\"status\":\"late\",\"note\":\"traffic\"},{\"studentId\":\"$STUD2\",\"status\":\"present\",\"note\":\"\"}]}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/attendance?schoolId=$SCHOOLID&classId=$SSS1&day=$TODAY" -H "Authorization: Bearer $STOKEN" \
  | jsonget "[e for e in d['entries'] if e['studentId']=='$STUD1'][0]['status']" | grep -q "late"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/attendance-summary?schoolId=$SCHOOLID&classId=$SSS1&from=$TODAY&to=$TODAY" \
  -H "Authorization: Bearer $STOKEN" | jsonget "[r for r in d['summary'] if r['studentId']=='$STUD1'][0]['rate']" | grep -q "^100$"

step "school: bulk-notes pour (long hyphens normalized server-side)"
BSUB=$(printf '%s' "$SUBS" | jsonget "[s['id'] for s in d['subjects'] if s['name']=='Basic Science'][0]" 2>/dev/null || printf '%s' "$SUBS" | jsonget "[s['id'] for s in d['subjects'] if s['name'].startswith('Basic')][0]")
python3 - "$BASE" "$STOKEN" "$SCHOOLID" "$JSS1" "$BSUB" << 'PYEOF'
import json, sys, urllib.request
base, token, school_id, class_id, subject_id = sys.argv[1:6]
topics = [
    {"title": "Living things", "week": 1, "content": "Living things breathe, feed and grow - a simple note.", "source": "e2e"},
    {"title": "Measurement", "week": 2, "content": "Length - mass - time: the base quantities of science.", "source": "e2e"},
]

def pour(overwrite):
    body = json.dumps({
        "classId": class_id, "subjectId": subject_id, "term": 1, "session": "2025/2026",
        "overwrite": overwrite, "topics": topics,
    }).encode()
    req = urllib.request.Request(base + f"/school/bulk-notes?schoolId={school_id}", data=body, method="POST",
                                 headers={"Content-Type": "application/json", "Authorization": "Bearer " + token,
                                          "User-Agent": "RenanceE2E/1.0 (CI probe)"})
    return json.loads(urllib.request.urlopen(req, timeout=30).read().decode())

res = pour(False)
assert res["written"] == 2, res
# re-pour with overwrite=false must not clobber: 0 topics written this call
res = pour(False)
assert res["written"] == 0, res
# overwrite=true replaces: 2 topics written again
res = pour(True)
assert res["written"] == 2, res
print("bulk-notes upsert OK")
PYEOF

step "school: fill results, finalize, PIN check"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/result-item?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"studentId\":\"$STUD1\",\"classId\":\"$SSS1\",\"subjectId\":\"$ENG\",\"term\":1,\"session\":\"2025/2026\",\"ca1\":15,\"ca2\":12,\"exam\":45}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/result-item?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"studentId\":\"$STUD2\",\"classId\":\"$SSS1\",\"subjectId\":\"$ENG\",\"term\":1,\"session\":\"2025/2026\",\"ca1\":10,\"ca2\":10,\"exam\":30}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/finalize?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"term\":1,\"session\":\"2025/2026\"}" | jsonget "d['finalized']" | grep -q "^2$"
SHEET=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/result-sheet?schoolId=$SCHOOLID&studentId=$STUD1&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN")
[ "$(printf '%s' "$SHEET" | jsonget "d['result']['status']")" = "finalized" ]
[ "$(printf '%s' "$SHEET" | jsonget "d['result']['schoolName']")" = "$SCHOOLNAME" ]
PIN=$(printf '%s' "$SHEET" | jsonget "d['result']['pin']")
[ ${#PIN} = "6" ]
CHECK=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/check-result?pin=$PIN&term=1&session=2025/2026")
printf '%s' "$CHECK" | jsonget "d['result']['studentName']" | grep -q "Ada Obi"
printf '%s' "$CHECK" | jsonget "d['result']['schoolLogoUrl']" | grep -q "^data:image/png"

step "school: fees, price a school-wide charge + a class charge"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/fee?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"\",\"title\":\"School fees\",\"description\":\"Term tuition\",\"amountNaira\":\"15000\",\"term\":1,\"session\":\"2025/2026\"}" \
  | jsonget "d['fee']['amountKobo']" | grep -q "^1500000$"
FEE2=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/fee?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"title\":\"Lab levy\",\"description\":\"\",\"amountNaira\":\"2500.50\",\"term\":1,\"session\":\"2025/2026\"}" \
  | jsonget "d['fee']['id']")
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/fees?schoolId=$SCHOOLID&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN" | jsonget "len(d['fees'])")" = "2" ]

step "school: fees, receipt recorded and balances sum right"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/fee-payment?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"feeId\":\"$FEE2\",\"studentId\":\"$STUD1\",\"amountNaira\":\"2500.50\",\"method\":\"transfer\",\"reference\":\"E2E-1\"}" \
  | jsonget "d['payment']['amountKobo']" | grep -q "^250050$"
BAL=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/fee-balances?schoolId=$SCHOOLID&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN")
[ "$(printf '%s' "$BAL" | jsonget "[b for b in d['balances'] if b['studentId']=='$STUD1'][0]['paidKobo']")" = "250050" ]
[ "$(printf '%s' "$BAL" | jsonget "[b for b in d['balances'] if b['studentId']=='$STUD1'][0]['outstandingKobo']")" = "1500000" ]
# a paid fee refuses deletion
curl -A "RenanceE2E/1.0 (CI probe)" -sS -o /dev/null -w '%{http_code}' -X DELETE "$BASE/school/fee?schoolId=$SCHOOLID&id=$FEE2" \
  -H "Authorization: Bearer $STOKEN" | grep -q "^409$"

step "school: timetable, save a week and read it back"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/timetable?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"slots\":[{\"day\":1,\"period\":1,\"startTime\":\"8:00\",\"endTime\":\"8:40\",\"subjectId\":\"$ENG\",\"label\":\"\"},{\"day\":1,\"period\":2,\"startTime\":\"8:40\",\"endTime\":\"9:20\",\"subjectId\":\"\",\"label\":\"Break\"}]}" \
  | jsonget "d['saved']" | grep -q "^2$"
TT=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/timetable?schoolId=$SCHOOLID&classId=$SSS1" -H "Authorization: Bearer $STOKEN")
[ "$(printf '%s' "$TT" | jsonget "len(d['timetable']['slots'])")" = "2" ]
printf '%s' "$TT" | jsonget "[s for s in d['timetable']['slots'] if s['period']==1][0]['subjectId']" | grep -q "$ENG"

step "school: ID cards, single issue, batch fill, revoke, reactivate"
CARD=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/id-card?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"studentId\":\"$STUD1\",\"session\":\"2025/2026\"}")
SERIAL1=$(printf '%s' "$CARD" | jsonget "d['card']['serial']")
printf '%s' "$SERIAL1" | grep -qE "^REN-[0-9]{4}-[0-9]{6}$"
# re-issue is idempotent: same serial comes back
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/id-card?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"studentId\":\"$STUD1\",\"session\":\"2025/2026\"}" \
  | jsonget "d['card']['serial']" | grep -q "$SERIAL1"
# batch fills the other student
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/id-cards?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"session\":\"2025/2026\"}" | jsonget "d['issued']")" = "1" ]
CARDID=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/id-cards?schoolId=$SCHOOLID&session=2025/2026" -H "Authorization: Bearer $STOKEN" \
  | jsonget "[c for c in d['cards'] if c['card']['serial']=='$SERIAL1'][0]['card']['id']")
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PUT "$BASE/school/id-card?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"cardId\":\"$CARDID\",\"status\":\"revoked\"}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/id-cards?schoolId=$SCHOOLID&session=2025/2026" -H "Authorization: Bearer $STOKEN" \
  | jsonget "[c for c in d['cards'] if c['card']['serial']=='$SERIAL1'][0]['card']['status']" | grep -q "revoked"

step "school: exam bank, add questions, publish paper, draw it"
for i in 1 2 3 4 5; do
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/exam-question?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"subjectId\":\"$ENG\",\"band\":\"senior\",\"term\":1,\"session\":\"2025/2026\",\"question\":\"E2E question $i: which option is the answer?\",\"options\":[\"Alpha\",\"Beta\",\"Gamma\",\"Delta\"],\"answerIndex\":1,\"explanation\":\"Beta is right.\",\"marks\":1}" >/dev/null
done
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/exam-questions?schoolId=$SCHOOLID&subjectId=$ENG&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN" | jsonget "len(d['questions'])")" = "5" ]
EXAM=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/exam?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"subjectId\":\"$ENG\",\"term\":1,\"session\":\"2025/2026\",\"title\":\"E2E paper\",\"durationMinutes\":45,\"questionCount\":4}" \
  | jsonget "d['exam']['id']")
PAPER=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/exam-paper?schoolId=$SCHOOLID&id=$EXAM" -H "Authorization: Bearer $STOKEN")
[ "$(printf '%s' "$PAPER" | jsonget "len(d['questions'])")" = "4" ]
printf '%s' "$PAPER" | jsonget "d['exam']['className']" | grep -q "SSS 1"
# republishing the same class+subject+term updates instead of duplicating
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/exam?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"classId\":\"$SSS1\",\"subjectId\":\"$ENG\",\"term\":1,\"session\":\"2025/2026\",\"title\":\"E2E paper v2\",\"durationMinutes\":50,\"questionCount\":3}" >/dev/null
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/exams?schoolId=$SCHOOLID&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN" | jsonget "len(d['exams'])")" = "1" ]
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/exams?schoolId=$SCHOOLID&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN" \
  | jsonget "d['exams'][0]['questionCount']" | grep -q "^3$"
# double-dash input is stored clean
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/exam-question?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"subjectId\":\"$ENG\",\"band\":\"\",\"term\":1,\"session\":\"2025/2026\",\"question\":\"Dash test -- still clean?\",\"options\":[\"Yes\",\"No\"],\"answerIndex\":0,\"explanation\":\"\",\"marks\":1}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/exam-questions?schoolId=$SCHOOLID&subjectId=$ENG&term=1&session=2025/2026" -H "Authorization: Bearer $STOKEN" \
  | jsonget "[q for q in d['questions'] if 'Dash test' in q['question']][0]['question']" | grep -q "Dash test - still clean?"

step "school: seed schemes drafts NERDC weeks into empty syllabuses"
# the curriculum was seeded earlier; class+subject pairs exist. The
# seed creates syllabuses for the session and drafts week topics.
[ "$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/school/seed-schemes?schoolId=$SCHOOLID" \
  -H "Authorization: Bearer $STOKEN" -H 'Content-Type: application/json' \
  -d "{\"schoolId\":\"$SCHOOLID\",\"session\":\"2025/2026\"}" | jsonget "d['filled']")" -ge "1" ]
# a syllabus now carries a scheme row with week 1
SYL=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/syllabus?schoolId=$SCHOOLID&classId=$SSS1&subjectId=$ENG" -H "Authorization: Bearer $STOKEN")
printf '%s' "$SYL" | jsonget "d['terms'][0]['schemeOfWork'][0]['topic']" | grep -qE "."

step "school: offline pack builds for the app (syllabus + exam bank + version)"
# the mobile app's SchoolController.download() hits GET /school/pack/:id,
# persists the JSON into SQLite and every school page then reads offline.
# Founder check 2026-10-03: "is the mobile app offline for school pages
# and teachers working well" - this is the pipeline proof.
PACK=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/school/pack/$SCHOOLID" -H "Authorization: Bearer $STOKEN")
[ "$(printf '%s' "$PACK" | jsonget "len(d['classes'])")" -ge 1 ]
[ "$(printf '%s' "$PACK" | jsonget "len(d['syllabus'])")" -ge 1 ]
[ "$(printf '%s' "$PACK" | jsonget "len(d['examBank'])")" -ge 1 ]
printf '%s' "$PACK" | jsonget "d['version']" | grep -qE "^[0-9]+-[0-9]+-[0-9]{14}$"
printf '%s' "$PACK" | jsonget "d['fetchedAt']" | grep -qE "^20[0-9]{2}-"
# a syllabus branch carries a class + subject name so the app pickers work
printf '%s' "$PACK" | jsonget "d['syllabus'][0]['className']" | grep -qE "."

# --- Learn module (founder directive 2026-10-14): the desk that ate the
# first tap, the LIVE quests, the guarded shop wallet and the REAL-only
# league board. Every assertion here is a regression net for bugs the
# founder hit on the live site. ---
AUTHH="Authorization: Bearer $TOKEN"

step "learn: first desk save STICKS (regression: the eaten first tap)"
DESK=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PATCH "$BASE/learn/profile" \
  -H "$AUTHH" -H 'Content-Type: application/json' \
  -d '{"setDesk":true,"institutionType":"University","department":""}')
printf '%s' "$DESK" | jsonget "d['institutionType']" | grep -q "University"

step "learn: departments seed waits in the background, then lists"
DEPTS="[]"
for _ in $(seq 1 150); do
  DEPTS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/departments?itype=University" -H "$AUTHH")
  N=$(printf '%s' "$DEPTS" | jsonget "len(d['departments'])")
  [ "$N" -ge 1 ] && break
  sleep 2
done
[ "$N" -ge 1 ]
DEPT=$(printf '%s' "$DEPTS" | jsonget "d['departments'][0]['id']")

step "learn: department save sticks + reads back from the DB"
curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X PATCH "$BASE/learn/profile" \
  -H "$AUTHH" -H 'Content-Type: application/json' \
  -d "{\"setDesk\":true,\"institutionType\":\"University\",\"department\":\"$DEPT\"}" >/dev/null
curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/profile" -H "$AUTHH" \
  | jsonget "d['institutionType'] + '/' + d['department']" | grep -q "University/"

step "learn: mismatched department rejected (Polytechnic desk, University dept)"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X PATCH "$BASE/learn/profile" \
  -H "$AUTHH" -H 'Content-Type: application/json' \
  -d "{\"setDesk\":true,\"institutionType\":\"Polytechnic\",\"department\":\"$DEPT\"}")
[ "$CODE" = "400" ]

step "learn: course desk shelf answers"
SHELF=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/course-desk" -H "$AUTHH")
SHELFN=$(printf '%s' "$SHELF" | python3 -c "
import json,sys
d=json.load(sys.stdin)
n=0
for k in ('general','departmental','national','department','shelves','courses'):
    v=d.get(k)
    if isinstance(v,list): n+=len(v)
    elif isinstance(v,dict): n+=sum(len(x) for x in v.values() if isinstance(x,list))
print(n)")
[ "$SHELFN" -ge 1 ]

step "learn: course path serves a real topic id"
COURSE=$(printf '%s' "$SHELF" | python3 -c "
import json,sys
d=json.load(sys.stdin)
cid=None
def hunt(o):
    global cid
    if isinstance(o,dict):
        if o.get('id') and o.get('topicCount') is not None and cid is None: cid=o['id']
        for v in o.values(): hunt(v)
    elif isinstance(o,list):
        for v in o: hunt(v)
hunt(d)
print(cid or '')")
[ -n "$COURSE" ]
# course ids carry spaces ("GST 103") - the URL needs them encoded
COURSE_ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$COURSE")
PATHJ=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/courses/$COURSE_ENC" -H "$AUTHH")
TOPIC=$(printf '%s' "$PATHJ" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for t in d.get('topics') or []:
    if t.get('id'):
        print(t['id']); break
else:
    print('')")
[ -n "$TOPIC" ]

step "learn: completing a topic pays XP into the LIVE quest counters (not mock)"
PROG=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/learn/progress" \
  -H "$AUTHH" -H 'Content-Type: application/json' \
  -d "{\"topicId\":\"$TOPIC\",\"correct\":10,\"total\":10,\"maxCombo\":3}")
printf '%s' "$PROG" | jsonget "d['xpEarned']" | grep -qE "^[0-9]+$"
# Date-proof quest check: the 3-of-7 daily rotation is seeded by the
# calendar day, so an 'xp'-kind quest is NOT guaranteed to be in today's
# set (2026-10-15 rolled {lessons, practice, combo} and this check
# failed on a rotation, not on the code). A perfect 10/10 lesson always
# increments at least two of xp/correct/lessons/perfect/combo - the
# pool carries exactly one 'practice' quest, so at most one of the
# three dailies can stay at zero. Sum ALL dailies instead of the
# kind='xp' subset.
XPQ1=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/quests" -H "$AUTHH" \
  | jsonget "sum(q['progress'] for q in d['daily'])")
[ "$XPQ1" -ge 1 ]

step "learn: quest catalogue serves 3 dailies + weekly + monthly"
QUESTS=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/quests" -H "$AUTHH")
[ "$(printf '%s' "$QUESTS" | jsonget "len(d['daily'])")" -eq 3 ]
printf '%s' "$QUESTS" | jsonget "d['weekly']['key']" | grep -q "weekly_xp_250"
printf '%s' "$QUESTS" | jsonget "d['monthly']['key']" | grep -q "monthly_xp_1000"

step "learn: a finished quest CLAIMS gems into the live wallet"
# Any daily whose progress crossed its target is claimable right now;
# the claim must pay gems and mark the row claimed (PK-guarded).
CLAIMABLE=$(printf '%s' "$QUESTS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
done=[q['key'] for q in d['daily'] if q.get('complete')]
print(done[0] if done else '')")
if [ -n "$CLAIMABLE" ]; then
  CKEY="$CLAIMABLE"
  GEMS_BEFORE=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/shop" -H "$AUTHH" | jsonget "d['gems']")
  CLAIM=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS -X POST "$BASE/learn/quests" \
    -H "$AUTHH" -H 'Content-Type: application/json' -d "{\"questKey\":\"$CKEY\"}")
  [ "$(printf '%s' "$CLAIM" | jsonget "d['gems']")" -ge 1 ]
  curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/shop" -H "$AUTHH" \
    | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['gems'] > $GEMS_BEFORE, f\"gems did not grow: {d['gems']} <= $GEMS_BEFORE\"
print('gems grew after claim')"
  # claiming twice must refuse, never double-pay
  CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/learn/quests" \
    -H "$AUTHH" -H 'Content-Type: application/json' -d "{\"questKey\":\"$CKEY\"}")
  [ "$CODE" = "400" ]
else
  echo "no daily finished yet today (deterministic pick) - claim path covered by unit tests"
fi

step "learn: shop wallet is LIVE (gems read + guarded buy refuses an empty wallet)"
SHOP=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/shop" -H "$AUTHH")
printf '%s' "$SHOP" | jsonget "d['gems']" | grep -qE "^[0-9]+$"
[ "$(printf '%s' "$SHOP" | jsonget "len(d['items'])")" -eq 3 ]
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' -X POST "$BASE/learn/shop" \
  -H "$AUTHH" -H 'Content-Type: application/json' -d '{"item":"freeze"}')
[ "$CODE" = "400" ]

step "learn: league board is REAL-only (regression: the 30 synthetic rivals)"
LEAGUE=$(curl -A "RenanceE2E/1.0 (CI probe)" -fsS "$BASE/learn/leaderboard" -H "$AUTHH")
printf '%s' "$LEAGUE" | jsonget "d['entries'][0]['isYou']" | grep -q "True"
FAKES=$(printf '%s' "$LEAGUE" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(sum(1 for e in d['entries'] if not e.get('isYou') and not e.get('username')))")
[ "$FAKES" -eq 0 ]
printf '%s' "$LEAGUE" | jsonget "d['league']" | grep -qE "^(Bronze|Copper|Silver|Gold|Sapphire|Ruby|Emerald|Amethyst|Pearl|Diamond)$"

step "learn: league without token -> 401"
CODE=$(curl -A "RenanceE2E/1.0 (CI probe)" -s -o /dev/null -w '%{http_code}' "$BASE/learn/leaderboard")
[ "$CODE" = "401" ]

printf 'ALL E2E STEPS GREEN, %s\n' "$BASE"
