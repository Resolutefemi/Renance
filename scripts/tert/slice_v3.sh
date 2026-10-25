#!/bin/bash
# slice_v3.sh — ONE idempotent, time-boxed slice of the v3 rebuild.
# Designed for the sandbox: every Bash call is killed at timeout, so this
# script makes incremental progress and relies 100% on disk state to resume:
#   - farm:        a gen lesson file existing = task done
#   - conversion:  converted_packs.txt marker per pack
#   - R2 push:     pack_done.txt ledger + shard files consumed on success
# Stages, checked in order on every invocation:
#   0. report exists -> done
#   1. one-time init (fresh shard space)
#   2. farm slice (timeout-bounded; resumable)
#   3. sweep once pending=0
#   4. convert any newly-complete packs
#   5. push slices until shards dir empty
#   6. verify -> v3_final_report.txt
set -u
export PYTHONUNBUFFERED=1
TERT=/home/z/my-project/scripts/tert
GEN=/home/z/my-project/scripts/tert/gen
BUILD=/home/z/my-project/content/tertiary/build
CONV=$BUILD/converted_packs.txt
REPORT=$BUILD/v3_final_report.txt
BUDGET=${1:-560}
PACKS="accounting_finance agriculture arts bio_sciences business chem_phys computing_general computing_python data_analytics economics education eng_chemical eng_civil eng_electrical eng_mechanical english_lang environment law medicine networking social_sciences"

status_line() {
  local pend conv_left shards
  pend=$(python3 "$GEN/farm.py" --status 2>/dev/null | head -1 | sed 's/.*remaining=//')
  conv_left=21; [ -f "$CONV" ] && conv_left=$(comm -23 <(echo "$PACKS" | tr ' ' '\n' | sort) <(sort "$CONV") | wc -l)
  shards=$(ls "$BUILD/shards" 2>/dev/null | wc -l)
  echo "STATUS pending=$pend packs_to_convert=$conv_left shards_left=$shards report=$([ -f "$REPORT" ] && echo yes || echo no)"
}

[ -f "$REPORT" ] && { echo "ALREADY DONE"; status_line; exit 0; }
cd "$GEN"
T0=$(date +%s)
LEFT() { echo $(( BUDGET - $(date +%s) + T0 )); }

# ---- stage 1: one-time init ----
if [ ! -f "$BUILD/.v3_started" ]; then
  rm -f "$BUILD/pack_done.txt"
  rm -rf "$BUILD/shards"
  touch "$BUILD/.v3_started"
  : > "$CONV"
  echo "init: fresh shard space at $(date -u +%T)"
fi

# ---- stage 2: farm slice ----
PENDING=$(python3 "$GEN/farm.py" --status 2>/dev/null | head -1 | sed 's/.*remaining=//')
if [ -f "$BUILD/.v3_force" ]; then PENDING=0; fi
if [ "${PENDING:-0}" != "0" ] && [ "$(LEFT)" -gt 90 ]; then
  echo "--- farm slice $(date -u +%T), budget ${BUDGET}s ---"
  FS=$(( BUDGET * 7 / 10 ))
  HALF=$(( FS / 2 ))
  PS0=$(date +%s)
  while [ "$(date +%s)" -lt "$((PS0 + HALF))" ]; do
    if python3 -c "
import sys; sys.path.insert(0, '/home/z/my-project/scripts/tert/gen')
from zai_client import chat
try:
    chat('Reply OK.', 'Say OK.', model='glm-4-flash', max_tokens=8, retries=1, timeout=25)
    sys.exit(0)
except Exception:
    sys.exit(1)
"; then echo "probe: API OK"; break; fi
    sleep 25
  done
  timeout "$FS" python3 farm.py --workers 3 --max-fail 40
  echo "farm slice rc=$? at $(date -u +%T)"
  PENDING=$(python3 "$GEN/farm.py" --status 2>/dev/null | head -1 | sed 's/.*remaining=//')
fi

# ---- stage 3: sweep once complete ----
if [ "${PENDING:-0}" = "0" ] && [ ! -f "$BUILD/.v3_swept" ]; then
  echo "--- sweep $(date -u +%T) ---"
  python3 "$TERT/sweep_validate.py"; SW=$?
  touch "$BUILD/.v3_swept"
  echo "sweep rc=$SW (1 = minor incomplete packs; complete packs still push)"
fi

# ---- stage 4: convert packs (gen_ready packs always; ALL packs when forced) ----
if [ -f "$BUILD/.v3_force" ]; then
  READY="$PACKS"
else
  READY=$(python3 - <<'PYEOF'
import sys
sys.path.insert(0, "/home/z/my-project/scripts")
from tert import build_lesson
PACKS = "accounting_finance agriculture arts bio_sciences business chem_phys computing_general computing_python data_analytics economics education eng_chemical eng_civil eng_electrical eng_mechanical english_lang environment law medicine networking social_sciences".split()
print("\n".join(pk for pk in PACKS if build_lesson.gen_ready(pk)))
PYEOF
)
fi
for pk in $READY; do
  [ "$(LEFT)" -lt 90 ] && break
  grep -qx "$pk" "$CONV" 2>/dev/null && continue
  BLOBMARK="$BUILD/.blobs_$pk"
  if [ ! -f "$BLOBMARK" ]; then
    echo "--- build $pk $(date -u +%T) ---"
    if python3 "$TERT/build_all.py" --only "$pk" --workers 6; then
      touch "$BLOBMARK"
    else
      echo "build $pk FAILED"; break
    fi
  fi
  echo "--- convert $pk $(date -u +%T), left $(LEFT)s ---"
  timeout "$(LEFT)" python3 "$TERT/convert_par.py"
  if ! ls "$BUILD"/blobs_*.jsonl >/dev/null 2>&1; then
    echo "$pk" >> "$CONV"; rm -f "$BLOBMARK"
    echo "converted $pk fully"
  fi
  [ "$(LEFT)" -lt 90 ] && break
done

# ---- stage 5: push slices (ledger-resumable) ----
if [ -f "$BUILD/.v3_swept" ] || [ -f "$BUILD/.v3_force" ]; then
  NCONV=$(wc -l < "$CONV")
  if [ "$NCONV" -eq 21 ] || { [ -f "$BUILD/.v3_force" ] && [ "$NCONV" -gt 0 ]; }; then
    if [ "$(LEFT)" -gt 120 ] && [ "$(ls "$BUILD/shards" 2>/dev/null | wc -l)" -gt 0 ]; then
      echo "--- R2 push slice $(date -u +%T) ---"
      timeout "$(LEFT)" python3 "$TERT/push_r2.py"
      echo "push slice rc=$? at $(date -u +%T)"
    fi
    # ---- stage 6: verify when drained ----
    if [ "$(ls "$BUILD/shards" 2>/dev/null | wc -l)" -eq 0 ] && [ ! -f "$REPORT" ]; then
      echo "--- verify $(date -u +%T) ---"
      python3 "$TERT/verify_samples.py"; VR=$?
      echo "verify rc=$VR"
      [ $VR -eq 0 ] && touch "$REPORT"
    fi
  fi
fi
status_line
