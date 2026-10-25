#!/bin/bash
# chain.sh — farm in 9.5-minute chunks until the corpus is complete, then
# rebuild and push. Resumable at every boundary; safe to re-run anytime.
# Usage: bash chain.sh [max_minutes]
set -u
cd /tmp/my-project/scripts/tert/gen
MAXMIN="${1:-999999}"
START=$(date +%s)

while true; do
  python3 - << 'PY'
import json, os, sys
sys.path.insert(0, '/tmp/my-project/scripts/tert/gen')
tasks = json.load(open('/tmp/my-project/content/tertiary/gen/tasks.json'))
done = sum(1 for t in tasks if os.path.exists(
    '/tmp/my-project/content/tertiary/gen/%s/%s.json' % (t['pack'], t['id'].replace('/', '__'))))
print('PROGRESS %d/%d' % (done, len(tasks)))
sys.exit(0 if done < len(tasks) else 1)
PY
  INCOMPLETE=$?
  if [ "$INCOMPLETE" -eq 0 ]; then
    NOW=$(date +%s); ELAPSED=$(( (NOW - START) / 60 ))
    if [ "$ELAPSED" -ge "$MAXMIN" ]; then
      echo "time budget reached, corpus still incomplete"
      exit 0
    fi
    timeout 565 python3 -u farm.py --workers 2 >> /tmp/my-project/content/tertiary/gen/chain_farm.log 2>&1
  else
    echo "corpus complete: rebuilding and pushing"
    cd /tmp/my-project/scripts/tert
    python3 build_all.py --workers 6 >> /tmp/my-project/content/tertiary/gen/chain_build.log 2>&1
    python3 push_r2.py >> /tmp/my-project/content/tertiary/gen/chain_push.log 2>&1
    echo "DONE: rebuild + full push finished"
    exit 0
  fi
done
