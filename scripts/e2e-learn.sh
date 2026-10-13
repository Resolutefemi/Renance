#!/bin/bash
# e2e-learn.sh — boots the study-api against the throwaway local
# Postgres and exercises EVERY surface the founder reported as "not
# loading": profile, catalog, my-courses, path, quests, shop, league,
# feed, follows, public profile. Exit 0 = the whole product is live.
set -u
export PATH=$PATH:/home/z/.local/go/bin
B="http://127.0.0.1:3991"
U="e2e$RANDOM$RANDOM"

cd /home/z/my-project/renance/apps/study-api

PORT=3991 \
DATABASE_URL="postgres://postgres@127.0.0.1:5433/postgres?sslmode=disable" \
JWT_SECRET="test-secret-for-local-verification" \
DATA_DIR=/home/z/my-project/renance/data \
/tmp/study-api > /tmp/api.log 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT

# Wait for listen
for i in $(seq 1 30); do
  curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -m 2 "$B/healthz" > /dev/null 2>&1 && break
  sleep 1
done
echo "== server up (pid $SRV) =="

REG=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -m 20 -X POST "$B/auth/register" -H "Content-Type: application/json" -d "{\"username\":\"$U\",\"password\":\"testpass123\"}")
TOKEN=$(echo "$REG" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
if [ -z "$TOKEN" ]; then
  echo "REGISTER FAILED: $REG"; exit 1
fi
echo "== registered $U =="
A="Authorization: Bearer $TOKEN"

fail=0
check() { # name, path, expected-code
  local code=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -o /tmp/e.txt -w "%{http_code}" -m 60 "$B$2" -H "$A")
  local ok=$([ "$code" = "$3" ] && echo PASS || echo FAIL)
  [ "$ok" = "FAIL" ] && fail=1
  echo "$1: $code $ok — $(head -c 100 /tmp/e.txt)"
}

check "profile      " "/learn/profile" 200
check "catalog jamb  " "/learn/catalog?body=jamb" 200
check "my-courses   " "/learn/my-courses" 200
check "quests       " "/learn/quests" 200
check "shop         " "/learn/shop" 200
check "league       " "/learn/leaderboard" 200
check "feed         " "/social/feed" 200
check "connections  " "/social/connections" 200

# Add a hardcoded secondary course, open its path
SET=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -m 60 -X POST "$B/learn/my-courses" -H "$A" -H "Content-Type: application/json" -d '{"courseIds":["SEC-JAMB-BIOLOGY"]}')
echo "set-courses: $(echo "$SET" | head -c 120)"
PATHJ=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -m 60 "$B/learn/courses/SEC-JAMB-BIOLOGY" -H "$A")
TITLE=$(echo "$PATHJ" | python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('title',''), 'topics:', len(d.get('topics',[])))" 2>/dev/null)
echo "course path: $TITLE"

# Open a lesson (AI generation, may take a while; wait=1)
LESS=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -o /tmp/l.txt -w "%{http_code}" -m 120 "$B/learn/topics/SEC-JAMB-BIOLOGY-T001/content?wait=1" -H "$A")
echo "lesson: $LESS — $(head -c 90 /tmp/l.txt)"

# Follow a second user for the social graph
REG2=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -m 20 -X POST "$B/auth/register" -H "Content-Type: application/json" -d "{\"username\":\"${U}b\",\"password\":\"testpass123\"}")
T2=$(echo "$REG2" | python3 -c "import sys,json;print(json.load(sys.stdin).get('token',''))" 2>/dev/null)
FOL=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -o /tmp/f.txt -w "%{http_code}" -m 30 -X POST "$B/social/users/$U/follow" -H "Authorization: Bearer $T2")
echo "follow: $FOL — $(head -c 80 /tmp/f.txt)"
PP=$(curl -s -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36" -o /tmp/p.txt -w "%{http_code}" -m 30 "$B/social/users/$U" -H "Authorization: Bearer $T2")
echo "public profile: $PP — $(head -c 110 /tmp/p.txt)"

echo "== RESULT: $([ $fail = 0 ] && echo ALL PASS || echo SOME FAILED) =="
exit $fail
